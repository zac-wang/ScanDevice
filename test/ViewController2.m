//
//  ViewController.m
//  test
//
//  Created by 王志超 on 2017/2/16.
//  Copyright © 2017年 王志超. All rights reserved.
//

#import "ViewController.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface ViewController ()

@end

#define PORT 5009 /*使用的port*/

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    
}

//自动扫瞄关联设备:通过udp的广播技术来实现
//app端主要代码：用户发送了一个广播以后再启动一个监听socket，负责搜集设备返回来的设备信息

//UDP Broadcast Sockets
- (IBAction)send:(id)sender {
    NSString* msg = @"whatTheFuck";
    
    int sock;
    struct sockaddr_in sa;
    int broadcast = 1;
    // if that doesn't work, try this
    //char broadcast = '1';
    
    /* Create the UDP socket */
    if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0)
    {
        printf("Failed to create socket\n");      return ;
    }
    
    /* Construct the server sockaddr_in structure */
    memset(&sa, 0, sizeof(sa));
    
    /* Clear struct */
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = inet_addr("255.255.255.255");
    sa.sin_port = htons(PORT);
    

    //通过IP_MULTICAST_IF,系统管理员可在安装的时候为组播创建默认的接口
    setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &sa, sizeof(sa));
    // this call is what allows broadcast packets to be sent:
    if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcast, sizeof broadcast) == -1) {
        perror("setsockopt (SO_BROADCAST)");
        exit(1);
    }
    
    u_char loop = 1; // 0:禁止回送，1:允许回送
    //IP_MULTICAST_LOOP网络参数控制IP层是否回送所送的数据，
//    setsockopt(sock,IPPROTO_IP,IP_MULTICAST_LOOP,&loop,sizeof(loop));
    
    char *cmsg = [msg UTF8String];
    if (sendto(sock, cmsg, strlen(cmsg), 0, (struct sockaddr *) &sa, sizeof(sa)) != strlen(cmsg))
    {
        printf("Mismatch in number of sent bytes\n");
        return ;
    }
    else
    {
        [NSThread detachNewThreadSelector:@selector(startServer)
                                 toTarget:self
                               withObject:nil];
        NSLog([NSString stringWithFormat:@"-> Tx: %@",msg]);
        return ;
    }
    
    
    
}
- (void)startServer {
    NSLog(@"UDP listen started...");
    int sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(sock_fd < 0)
    {
        printf("error: Create Socket Failed!");
        exit(EXIT_FAILURE);
    }
    struct sockaddr_in sa;
    char buffer[1024];
    size_t fromlen, recsize;
    
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = INADDR_ANY;
    sa.sin_port = htons(3000);
    
    // bind the socket to our address
    if (-1 == bind(sock_fd,(struct sockaddr *)&sa, sizeof(struct sockaddr)))
    {
        perror("error bind failed");
        close(sock_fd);
        exit(EXIT_FAILURE);
    }
    
    for (;;)
    {
        recsize = recvfrom(sock_fd, (void *)buffer, 1024, 0, (struct sockaddr *)&sa, &fromlen);
        
        if (recsize < 0)
        fprintf(stderr, "%s\n", strerror(errno));
        
        NSLog([NSString stringWithUTF8String:buffer]);
        
    }
}

//模拟设备端主要代码：程序一启动就有一个监听线程，当监听到广播信息后，从该端口报告数据上去
//UDP Server
- (void)startDeviceServer {
    int sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(sock_fd < 0)
    {
        printf("error: Create Socket Failed!");
        exit(EXIT_FAILURE);
    }
    struct sockaddr_in sock_addr;
    memset(&sock_addr, 0, sizeof(sock_addr));
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_addr.s_addr = INADDR_ANY;
    sock_addr.sin_port = htons(PORT);
    
    // bind the socket to our address
    if (-1 == bind(sock_fd,(struct sockaddr *)&sock_addr, sizeof(struct sockaddr)))
    {
        perror("error bind failed");
        close(sock_fd);
        exit(EXIT_FAILURE);
    }
    
    char buffer[1024];
    ssize_t recsize;
    struct sockaddr_in from;
    socklen_t fromlen;
    
    for (;;)
    {
        printf ("........等待接收数据........\n");
        bzero(buffer,sizeof(buffer));
        fromlen = sizeof(struct sockaddr);
        recsize = recvfrom(sock_fd, (void *)buffer, sizeof(buffer), 0, (struct sockaddr *)&from, &fromlen);
        if (recsize < 0){
            fprintf(stderr, "%s\n", strerror(errno));
            continue;
        }
        
        NSLog(@"%@", [NSString stringWithUTF8String:buffer]);
        
        // [self parseRX:[NSString stringWithFormat:@"<- Rx: %s",buffer]];
        
//        char str[INET_ADDRSTRLEN];
//        struct sockaddr_in  from;
//        inet_ntop(AF_INET, &sock_addr.sin_addr, str, INET_ADDRSTRLEN);
//        from.sin_family = AF_INET;
//        inet_pton(AF_INET, str, &from.sin_addr);
//        from.sin_port = htons(3000);
        
        char pResponse[] = "i am device no 1";
        int n = sendto(sock_fd, pResponse, strlen(pResponse), 0, (struct sockaddr *) &from, sizeof(from));
        if (n < 0) {
            perror("sendto");
        }
    }
    //[pool release];
}

- (IBAction)runDeviceServer {
    [NSThread detachNewThreadSelector:@selector(startDeviceServer) toTarget:self withObject:nil];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
