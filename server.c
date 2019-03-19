/*
 *  server.c
 *
 *  Simple FTP Server
 *  ====================
 *  If the client connects to the server and wants to retrieve a file
 *  with command "Get FILENAME", server retrieves iff the file exists
 *  on the server o/w notifies the client with an error message.
 *
 *  Compile & link  :   gcc server.c -lpthread -o server
 *  Execute         :   ./server
 *
 *  Ozcan Ovunc <ozcan_ovunc@hotmail.com>
 */

#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <sys/stat.h>
#include <sys/sendfile.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdbool.h>
#include <pthread.h>

#define SERVER_PORT 8080
#define CMD_SIZE 100

void* ConnectionHandler(void* socket_desc);
char* GetFilenameFromRequest(char* request);
bool SendFileOverSocket(int socket_desc, char* file_name);

int main(int argc, char **argv)
{
	int     socket_desc, 
		socket_client, 
		*new_sock, 
		c = sizeof(struct sockaddr_in);

	struct  sockaddr_in	server, client;

	// Create socket
	socket_desc = socket(AF_INET, SOCK_STREAM, 0);
	if (socket_desc == -1)
	{
		perror("Could not create socket");
		return 1;
	}

	server.sin_family = AF_INET;
	server.sin_addr.s_addr = INADDR_ANY;
	server.sin_port = htons(SERVER_PORT);

	if (bind(socket_desc, (struct sockaddr *)&server, sizeof(server)) < 0)
	{
		perror("Bind failed");
		return 1;
	}

	listen(socket_desc, 3);
	
	while (socket_client = accept(socket_desc, (struct sockaddr *)&client, (socklen_t*)&c))
	{
		pthread_t sniffer_thread;
		new_sock = malloc(1);
		*new_sock = socket_client;        
		pthread_create(&sniffer_thread, NULL, ConnectionHandler, (void*) new_sock);
		// pthread_join(sniffer_thread, NULL);
	}
	 
	if (socket_client<0)
	{
		perror("Accept failed");
		return 1;
	}

	return 0;
}

int GetCommandFromRequest(char* request)
{
	printf("%s\n", request);
	char cmd[CMD_SIZE];
	strcpy(cmd, request);
	int i = 0;
	while(request[i] != ' ' && request[i] != '\0')
	{
		i++;
	}

	if(request[i] == '\0')
		return 5;
	else
	{
		strncpy(cmd, request, i-1);
		cmd[i] = '\0';
	}
		
	if(!strcmp(cmd, "GET"))
		return 1;
	else if(!strcmp(cmd, "PUT"))
		return 2;
	else if(!strcmp(cmd, "MGET"))
		return 3;
	else if(!strcmp(cmd, "MPUT"))
		return 4;
	return 0;
}

void performGET(char *file_name, int socket)
{
	char server_response[BUFSIZ];
	// If requested file exists, notify the client and send it
	if (access(file_name, F_OK) != -1)
	{
		strcpy(server_response, "OK");
		write(socket, server_response, strlen(server_response));
		SendFileOverSocket(socket, file_name);
	}
	else
	{
		// Requested file does not exist, notify the client
		strcpy(server_response, "NO");
		write(socket, server_response, strlen(server_response)); 
	}
}

void *ConnectionHandler(void *socket_desc)
{
	int	choice, file_desc, file_size;
	int socket = *(int*)socket_desc;
	char server_response[BUFSIZ], client_request[BUFSIZ], file_name[BUFSIZ];
	char *data;
	while(1)
	{
		recv(socket, client_request, BUFSIZ, 0);

		choice = GetCommandFromRequest(client_request);
		printf("%d\n", choice);
		switch(choice)
		{
			case 1:
			// ################### GET ###################
				strcpy(file_name, GetFilenameFromRequest(client_request));
				// printf("%s\n", file_name);
				performGET(file_name, socket);
				break;
			case 2:
			// ################### PUT ###################
				// Add check conditions
				strcpy(server_response, "OK");
				write(socket, server_response, strlen(server_response));
				strcpy(file_name, GetFilenameFromRequest(client_request));
				recv(socket, &file_size, sizeof(int), 0);
				data = malloc(file_size);
				file_desc = open(file_name, O_CREAT | O_EXCL | O_WRONLY, 0666);
				recv(socket, data, file_size, 0);
				write(file_desc, data, file_size);
				close(file_desc);
				break;
			case 3:
				break;
			case 4:
				break;
			case 5:
				break;
		}
	}
	free(socket_desc);   
	return 0;
}

char* GetFilenameFromRequest(char* request)
{
	char *file_name = strchr(request, ' ');
	return file_name + 1;
}

bool SendFileOverSocket(int socket_desc, char* file_name)
{
	struct stat	obj;
	int file_desc, file_size;

	stat(file_name, &obj);
	file_desc = open(file_name, O_RDONLY);
	file_size = obj.st_size;
	send(socket_desc, &file_size, sizeof(int), 0);
	sendfile(socket_desc, file_desc, NULL, file_size);

	return true;
}