//
//  ViewController.m
//  test
//
//  Created by  zac_wang@163.com on 2017/2/16.
//  Copyright © 2017年  zac_wang@163.com. All rights reserved.
//

#import "ViewController.h"
#import <ifaddrs.h>
#import <net/if.h>
#import <netinet/in.h>
#import <arpa/inet.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UITextView *showText;

@end

#define PORT 5009

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

}

#pragma mark - UDP Broadcast Sockets
#pragma mark app端扫瞄关联设备
- (IBAction)send:(id)sender {
    char *cmsg = "Are you a device?";
    
    int sock;
    struct sockaddr_in sa;
    if ((sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP)) < 0) {
        printf("Error Creating Socket");
        exit(EXIT_FAILURE);
    }
    
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = htonl(INADDR_BROADCAST);
    sa.sin_port = htons(PORT);
    
    setsockopt(sock, IPPROTO_IP, IP_MULTICAST_IF, &sa, sizeof(sa));
    
    int bBroadcast = 1;
    if (setsockopt(sock, SOL_SOCKET, SO_BROADCAST, (const char*)&bBroadcast,sizeof(bBroadcast)) == -1) {
        perror("setsockopt (SO_BROADCAST)");
        exit(EXIT_FAILURE);
    }
    
    struct linger m_sLinger;
    m_sLinger.l_onoff = 1;
    m_sLinger.l_linger = 5;
    setsockopt(sock,SOL_SOCKET,SO_LINGER,(const char*)&m_sLinger,sizeof(m_sLinger));
    
    if (sendto(sock, cmsg, (int)strlen(cmsg), 0,(struct sockaddr*)&sa, (int)sizeof (sa)) < 0){
        printf("Error sending packet: %s\n", strerror(errno));
        return;
    }else {
        static int f = 1;
        if(f){
            [NSThread detachNewThreadSelector:@selector(startServer) toTarget:self withObject:nil];
            f=0;
        }
        return;
    }
    close(sock);
}

- (void)startServer {
    int sock = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    struct sockaddr_in sa;
    char buffer[1024];
    size_t fromlen, recsize;
    
    memset(&sa, 0, sizeof(sa));
    sa.sin_family = AF_INET;
    sa.sin_addr.s_addr = INADDR_ANY;
    sa.sin_port = htons(3000);
    
    if (-1 == bind(sock,(struct sockaddr *)&sa, sizeof(struct sockaddr)))
    {
        perror("error bind failed");
        close(sock);
        exit(EXIT_FAILURE);
    }
    
    while (true) {
        recsize = recvfrom(sock, (void *)buffer, 1024, 0, (struct sockaddr *)&sa, &fromlen);
        
        if (recsize < 0)
            fprintf(stderr, "%s\n", strerror(errno));
        
        NSString *show = [NSString stringWithUTF8String:buffer];
        dispatch_sync(dispatch_get_main_queue(), ^(void) {
            self.showText.text = [self.showText.text stringByAppendingFormat:@"app端--收到设备回应:%@\n", show];
        });
    }
}

#pragma mark - UDP Server
- (IBAction)runDeviceServer:(UIButton *)sender {
    sender.enabled = NO;
    self.showText.text = @"";
    [NSThread detachNewThreadSelector:@selector(startDeviceServer) toTarget:self withObject:nil];
}

#pragma mark 模拟设备端
struct sockaddr_in sa;
- (void)startDeviceServer {
    int sock_fd = socket(PF_INET, SOCK_DGRAM, IPPROTO_UDP);
    if(sock_fd < 0)
    {
        printf("error: Create Socket Failed!");
        exit(EXIT_FAILURE);
    }
    
    struct sockaddr_in sock_addr;
    sock_addr.sin_family = AF_INET;
    sock_addr.sin_addr.s_addr = INADDR_ANY;
    sock_addr.sin_port = htons(PORT);
    memset(sock_addr.sin_zero, 0, sizeof(sock_addr.sin_zero));
    
    if (bind(sock_fd,(struct sockaddr *)&sock_addr, sizeof(struct sockaddr)) != 0)
    {
        perror("error bind failed");
        close(sock_fd);
        exit(EXIT_FAILURE);
    }
    
    char buffer[1024];
    ssize_t recsize;
    struct sockaddr_in from;
    socklen_t fromlen;
    for (;;) {
        bzero(buffer,sizeof(buffer));
        recsize = recvfrom(sock_fd, (void *)buffer, sizeof(buffer), 0, (struct sockaddr *)&from, &fromlen);
        if (recsize < 0){
            fprintf(stderr, "%s\n", strerror(errno));
            continue;
        }
        
        dispatch_async(dispatch_get_main_queue(), ^(void) {
            self.showText.text = [self.showText.text stringByAppendingFormat:@"设备--收到app端发起的响应\n"];
        });
        sleep(1);
        
        char *buffer_c  = buffer;
        char str[INET_ADDRSTRLEN];
        struct sockaddr_in  cms;
        int n;
        inet_ntop(AF_INET, &from.sin_addr, str, INET_ADDRSTRLEN);
        cms.sin_family = AF_INET;
        inet_pton(AF_INET, str, &cms.sin_addr);
        cms.sin_port = htons(3000);
        
        char *result = "我是目标设备1号";
        n = sendto(sock_fd, result, strlen(result), 0, (struct sockaddr *) &cms, sizeof(cms));
        if (n < 0) {
            perror("sendto");
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
