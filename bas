
/*
 *  client.c
 *
 *  Simple FTP Client
 *  ====================
 *  Connects the server, and sends a command "Get FILENAME" to retrieve
 *  the file. If the file exists on the server, client retrieves it.
 *
 *  Compile & link  :   gcc client.c -o client
 *  Execute         :   ./client
 *
 *  Ozcan Ovunc <ozcan_ovunc@hotmail.com>
 */

#include <stdio.h>
#include <sys/socket.h> 
#include <arpa/inet.h>
#include <sys/stat.h>
#include <sys/sendfile.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#include <dirent.h>
#include <stdio.h>
#include <string.h>

#define MAXFILE 100
#define SERVER_IP 	"127.0.0.1"
#define SERVER_PORT 	8080
#define FILENAME 100

int SendFileOverSocket(int socket_desc, char* file_name)
{
	struct stat	obj;
	int file_desc, file_size;

	stat(file_name, &obj);
	file_desc = open(file_name, O_RDONLY);
	file_size = obj.st_size;
	send(socket_desc, &file_size, sizeof(int), 0);
	sendfile(socket_desc, file_desc, NULL, file_size);

	return 1;
}

int main(int argc , char **argv)
{
	int 	socket_desc;
	struct 	sockaddr_in server;
	char 	request_msg[BUFSIZ], reply_msg[BUFSIZ], filename[MAXFILE];

	// Variables for the file being received
	int	file_size,
		file_desc;
	char	*data;
		
	socket_desc = socket(AF_INET, SOCK_STREAM, 0);
	if (socket_desc == -1)
	{
		perror("Could not create socket");
		return 1;
	}

	server.sin_addr.s_addr = inet_addr(SERVER_IP);
	server.sin_family = AF_INET;
	server.sin_port = htons(SERVER_PORT);

	// Connect to server
	if (connect(socket_desc, (struct sockaddr *)&server, sizeof(server)) < 0)
	{
		perror("Connection failed");
		return 1;
	}

	int choice = 0;
	while(1)
	{
		printf("Enter a choice:\n1- GET\n2- PUT\n3- MGET\n4- MPUT\n5- EXIT\n");
		scanf("%d", &choice);
		switch(choice)
		{
			case 1:
				printf("Enter filename to get: ");
				scanf("%s", filename);
				// Get a file from server
				strcpy(request_msg, "GET ");
				strcat(request_msg, filename);
				write(socket_desc, request_msg, strlen(request_msg));
				recv(socket_desc, reply_msg, 2, 0);
				
				printf("%s\n", reply_msg);
				// Start receiving file
				if (strcmp(reply_msg, "OK") == 0)
				{
					int abortflag = 0;
					if( access( filename, F_OK ) != -1 )
					{
    					printf("File already exists. Press 0 to overwrite. Press any other key to abort.\n");
    					scanf("%d", &abortflag);
					}
					recv(socket_desc, &file_size, sizeof(int), 0);
					data = malloc(file_size);
					file_desc = open(filename, O_CREAT | O_EXCL | O_WRONLY, 0666);
					recv(socket_desc, data, file_size, 0);
					if(abortflag == 0)
						write(file_desc, data, file_size);
					close(file_desc);
				}
				else
				{
					fprintf(stderr, "Bad request\n");
				}
				break;
			case 2:
				printf("Enter filename to put: ");
				scanf("%s", filename);
				// Get a file from server
				strcpy(request_msg, "PUT ");
				strcat(request_msg, filename);
				if (access(filename, F_OK) != -1)
				{
					write(socket_desc, request_msg, strlen(request_msg));
					recv(socket_desc, reply_msg, 2, 0);
					if (strcmp(reply_msg, "OK") == 0)
					{
						SendFileOverSocket(socket_desc, filename);
					}
					else
					{
						fprintf(stderr, "Server can't create file...\n");
					}
				}
				else
				{
					fprintf(stderr, "File not found locally...\n");
					break;
				}

				
				break;
				case 3:

				MGET(socket_desc);	
				break;
				case 4:
				MPUT(socket_desc);
				break;
			case 5:
				strcpy(request_msg,"EXIT");
				write(socket_desc, request_msg, strlen(request_msg));	
				return 0;
		}
	}

	return 0;
}

void MGET(int server_socket){

	char temp[MAXFILE],request_msg[MAXFILE];
	char* reply="OK";
	char file_name[100];
		scanf("%s",temp);

	strcpy(request_msg,"MGET ");
	strcat(request_msg,temp);
printf("%s\n", request_msg);
	write(server_socket, request_msg, strlen(request_msg));
	int file_name_size=0;
	while(1){
		recv(server_socket,&file_name_size,sizeof(int),0);
		write(server_socket,reply,2);
		recv(server_socket,file_name,file_name_size,0);
		file_name[file_name_size]='\0';
		write(server_socket,reply,2);
		if(strcmp(file_name,"END")==0)
			break;
		printf("%s\n", file_name);
		//	PerformGet(server_socket,file_name);


	}
	printf("Complete\n");

}

void MPUT(int server_socket){
char temp[MAXFILE],request_msg[MAXFILE];
	char* reply="OK";
	char file_name[100];
	scanf("%s",temp);
	strcpy(request_msg,"MPUT ");
	strcat(request_msg,temp);
	printf("%s\n", request_msg);
	write(server_socket, request_msg, strlen(request_msg));
	DIR *d;
   	char *p1,*p2;
    int ret;
    char file[BUFSIZ];
    struct dirent *dir;
    d = opendir(".");
    char full_name[100];
    strcpy(file_name,temp);
    if (d)
    {
        while ((dir = readdir(d)) != NULL)
        {
        	strcpy(full_name,dir->d_name);
            p1=strtok(dir->d_name,".");
            p2=strtok(NULL,".");
            if(p2!=NULL && strcmp(p2,file_name)==0){
           // 	PerformPut(server_socket,full_name);
			printf("%s\n", full_name);  
		
			int size = strlen(full_name);
        	write(server_socket, &size,sizeof(int));
			write(server_socket, full_name, strlen(full_name));
     		recv(server_socket, reply, 2, 0);

		}
      }
        strcpy(request_msg,"END");
       
        int size = strlen(request_msg);
        write(server_socket, &size,sizeof(int));
		write(server_socket, request_msg, strlen(request_msg));
     	recv(server_socket, reply, 2, 0);
       
        closedir(d);
}
    printf("Complete\n");

}
