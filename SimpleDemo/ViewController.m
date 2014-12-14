//
//  ViewController.m
//

#import <AVFoundation/AVFoundation.h>
#import "ViewController.h"
#import <AudioToolbox/AudioServices.h>
static BOOL isSleep = NO;
static int closeCount = 0;
//static int alertFlag = 0;
@interface ViewController ()
{
    int Status;
    HVC_FUNCTION ExecuteFlag;
    AVCaptureSession *captureSession;
}
@property HVC_BLE *HvcBLE;
@property (nonatomic) SystemSoundID wakeSound;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;

@end

@implementation ViewController

@synthesize HvcBLE = _HvcBLE;

- (void)viewDidLoad {
    Status = 0;
    ExecuteFlag = 0;
    [super viewDidLoad];
    [self setupSound];
    // Do any additional setup after loading the view, typically from a nib.
    self.HvcBLE = [[HVC_BLE alloc] init];
    self.HvcBLE.delegateHVC = self;
    
    _ResultTextView.text = @"";
    _statusLabel.text = @"Connecetしてください";
    
    [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(waken) userInfo:nil repeats:YES];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)pushButton:(UIButton *)sender {
    switch ( Status )
    {
        case 0:
            // disconnect -> connect
            [self.HvcBLE deviceSearch];
            [self.pushbutton setTitle:@"disconnect" forState:UIControlStateNormal ];
            Status = 1;
            break;
        case 1:
            // connect -> disconnect
            [self.HvcBLE disconnect];
            [self.pushbutton setTitle:@"connect" forState:UIControlStateNormal];
            Status = 0;
            return;
        case 2:
            return;
    }
    
    dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
        for (int i=0; i<10; i++) {
            sleep(1);
        }
        dispatch_semaphore_signal(semaphore);
    });
    
    dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
    //dispatch_release(semaphore);
    
    // アラートを作る
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"デバイス接続"
                                              message:@"選択してください"
                                              delegate:self
                                              cancelButtonTitle:@"cancel"
                                              otherButtonTitles:nil];
    
    NSMutableArray *deviseList = [self.HvcBLE getDevices];
    for( int i = 0; i < deviseList.count; i++ )
    {
        NSString *name = ((CBPeripheral *)deviseList[i]).name;
        [alert addButtonWithTitle:name];
    }
    
    // アラートを表示する
    [alert show];
}

// アラートの処理（デリゲートメソッド）
- (void) alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    
//    if (alertView.tag == 1) {
//        if (buttonIndex == 0) {
//            closeCount = 0;
//            alertFlag = 0;
//        }
//        
//    } else {
     if (buttonIndex == 0) {
        // キャンセルボタン
        NSLog(@"キャンセルされました");
        [self.pushbutton setTitle:@"connect" forState:UIControlStateNormal];
        Status = 0;
    } else {
        NSMutableArray *deviseList = [self.HvcBLE getDevices];
        [self.HvcBLE connect:deviseList[buttonIndex-1]];
        [self.pushbutton setTitle:@"disconnect" forState:UIControlStateNormal];
        Status = 1;
        _statusLabel.text = @"startを押してください";
    }
//}
}

- (IBAction)btnExecute_click:(UIButton *)sender {
    switch ( Status )
    {
        case 0:
            return;
        case 1:
            _statusLabel.text = @"デバイスが顔の前にくるようにしてください…";
            [self.btnExecution setTitle:@"stop" forState:UIControlStateNormal];
            Status = 2;
            break;
        case 2:
            _statusLabel.text = @"startをおしてください";
            [self.btnExecution setTitle:@"start" forState:UIControlStateNormal];
            Status = 1;
            return;
    }
    
    HVC_PRM *param = [[HVC_PRM alloc] init];
    param.face.MinSize = 60;
    param.face.MaxSize = 480;
    
    [self.HvcBLE setParam:param];
}

- (void)onConnected
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:@"接続しました"
                                                   delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
}
- (void)onDisconnected
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"SUCCESS" message:@"切断しました"
                                                   delegate:nil cancelButtonTitle:nil otherButtonTitles:@"OK", nil];
    [alert show];
}
- (void)onPostGetDeviceName:(NSData *)value
{
    
}

- (void)onPostSetParam:(HVC_ERRORCODE)err status:(unsigned char)outStatus
{
    dispatch_async(dispatch_get_main_queue(), ^{
        // 各フラグ参照
        ExecuteFlag = HVC_ACTIV_BODY_DETECTION | HVC_ACTIV_HAND_DETECTION | HVC_ACTIV_FACE_DETECTION
                        | HVC_ACTIV_FACE_DIRECTION | HVC_ACTIV_AGE_ESTIMATION | HVC_ACTIV_GENDER_ESTIMATION
                        | HVC_ACTIV_GAZE_ESTIMATION | HVC_ACTIV_BLINK_ESTIMATION | HVC_ACTIV_EXPRESSION_ESTIMATION;
        
        HVC_RES *res = [[HVC_RES alloc] init];
        [self.HvcBLE Execute:ExecuteFlag result:res];
    });
}
- (void)onPostGetParam:(HVC_PRM *)param errcode:(HVC_ERRORCODE)err status:(unsigned char)outStatus
{
    
}
- (void)onPostGetVersion:(HVC_VER *)ver errcode:(HVC_ERRORCODE)err status:(unsigned char)outStatus
{
    
}

-(void) onPostExecute:(HVC_RES *)result errcode:(HVC_ERRORCODE)err status:(unsigned char)outStatus
{
    NSLog(@"a");
    // 実行結果の受け取り
    NSString *resStr = @"";
    
    //if((err == HVC_NORMAL) && (outStatus == 0)){
        // 人体検出
        //resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"Body Detect = %d\n", result.sizeBody]];
        int i;
        
        // 顔検出と各種推定
        //resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"Face Detect = %d\n", result.sizeFace]];
        for(i = 0; i < result.sizeFace; i++){
            FaceResult *fd = [result face:i];
            // 顔検出
            if((result.executedFunc & HVC_ACTIV_FACE_DETECTION) != 0){
                
                resStr = [resStr stringByAppendingString:@"顔ある！！！\n"];
//
//                resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"  [Face Detection] : size = %d, ", fd.size]];
//                resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"x = %d, y = %d, ", fd.posX, fd.posY]];
//                resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"conf = %d\n", fd.confidence]];
            } else {
                resStr = [resStr stringByAppendingString:@"顔ない！！！\n"];
            }
            
            // 目つむり推定
            if((result.executedFunc & HVC_ACTIV_BLINK_ESTIMATION) != 0){
                          //     resStr = [resStr stringByAppendingString:@"目瞑ってる！！！！！\n"];
//               resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"  [Blink Estimation] : "]];
//                resStr = [resStr stringByAppendingString:[NSString stringWithFormat:@"ratioL = %d, ratioR = %d\n", fd.blink.ratioL, fd.blink.ratioR]];
                if ((int)fd.blink.ratioL > 600) {
                    closeCount++;
                    resStr = [resStr stringByAppendingString:@"目瞑ってる！！！！！\n"];
                    [self vibration];
                } else {
                    closeCount = 0;
                    resStr = [resStr stringByAppendingString:@"目あいてる！！！！！\n"];
                }
                [self detectSleeping];
            }
        }
    //}
    //_ResultTextView.text = resStr;

    if ( Status == 2 ) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.HvcBLE Execute:ExecuteFlag result:result];
        });
    }
}

- (void)setupSound
{
    NSString *path = [[NSBundle mainBundle] pathForResource:@"wakeSound" ofType:@"mp3"];
    NSURL *url = [NSURL fileURLWithPath:path];
    AudioServicesCreateSystemSoundID(CFBridgingRetain(url),&_wakeSound);
}

- (void)playWakeSound
{
    AudioServicesPlaySystemSound(_wakeSound);
}

- (void) vibration
{
    AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
}

//LEDライトを点灯
-(void)lightOn
{
    [captureSession startRunning];
    NSError *error = nil;
    AVCaptureDevice *captureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    [captureDevice lockForConfiguration:&error];
    captureDevice.torchMode = AVCaptureTorchModeOn;
    [captureDevice unlockForConfiguration];
}

//LEDライトを消灯
-(void)lightOff
{          NSError *offerror = nil;
    AVCaptureDevice *offcaptureDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
    
    [offcaptureDevice lockForConfiguration:&offerror];
    offcaptureDevice.torchMode = AVCaptureTorchModeOff;
    [offcaptureDevice unlockForConfiguration];
}

- (void) detectSleeping
{
    isSleep = closeCount > 0 ? YES : NO;
    if (isSleep) {
        _imageView.image = [UIImage imageNamed:@"sleep.jpeg"];
        _statusLabel.text = @"起きて！！";
        //self.view.backgroundColor = [UIColor redColor];
    } else {
        _imageView.image = [UIImage imageNamed:@"wake.jpeg"];
        _statusLabel.text = @"起きてます！！";
        //self.view.backgroundColor = [UIColor greenColor];
    }
}

- (void) waken
{
    if (isSleep) {
        /*
        if (alertFlag == 0) {
            [self wakeAlert];
        }
        alertFlag++;
        */
         [self vibration];
        if(closeCount > 1) {
            [self playWakeSound];
        }
        if(closeCount > 2) {
            [self lightOn];
            [self performSelector:@selector(lightOff) withObject:nil afterDelay:0.05];
        }
    }
}

/*
- (void) wakeAlert
{
    UIAlertView *aler =
    [[UIAlertView alloc] initWithTitle:@"起きてください" message:@"起きてください"
                              delegate:self cancelButtonTitle:@"起きた" otherButtonTitles:nil];
    aler.tag = 1;
    [aler show];
}
*/
 
- (IBAction)buttonTouched:(UIButton *)sender {
    _statusLabel.text = @"デバイス検出中…";
}

@end
