//
//  ViewController.swift
//  TestAsync
//
//  Created by wenjin on 8/24/16.
//  Copyright © 2016 wenjin. All rights reserved.
//

import UIKit
typealias AsyncFunc = (info : AnyObject,complete:(AnyObject?,NSError?)->Void) -> Void


infix operator <> {associativity left precedence 150}
infix operator +> {associativity left precedence 150}


func +>(left : AsyncFunc , right : AsyncFunc) -> AsyncFunc{
    return { info , complete in
        left(info: info){ result,error in
            guard error == nil else{
                complete(nil,error)
                return
            }
            right(info: info){result,error in
                complete(result,error)
            }
        }
    }
}

func <>(left : AsyncFunc , right : AsyncFunc) -> AsyncFunc{
    return { info, complete in
        
        var leftComplete = false
        var rightComplete = false
        var finishedComplete = false
        
        var leftResult:AnyObject? = nil
        var rightResult:AnyObject? = nil
        
        let checkComplete = {
            print ("checking")
            if leftComplete && rightComplete{
                objc_sync_enter(finishedComplete)
                if !finishedComplete{
                    let finalResult:[AnyObject] = [leftResult!, rightResult!]
                    complete(finalResult, nil)
                    finishedComplete = true
                }
                objc_sync_exit(finishedComplete)
            }
        }
        
        left(info: info){result,error in
            guard error == nil else{
                complete(nil, error)
                return
            }

            leftComplete = true
            leftResult = result;
            checkComplete()
        }
        
        right(info: info){result,error in
            guard error == nil else{
                complete(nil, error)
                return
            }

            rightComplete = true
            rightResult = result;
            checkComplete()
        }
    }
}

class Promise {
    var chain : AsyncFunc
    var alwaysClosure : (Void->Void)?
    var errorClosure : (NSError?->Void)?
    
    init(starter : AsyncFunc){
        chain = starter
    }
    
    func then(body : AnyObject throws->Void )->Promise{
        let async: AsyncFunc = { info, complete in
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)) {
                var error : NSError?
                do{
                    try body(info)
                }catch let err as NSError{
                    error = err
                }
                complete(0,error)
            }
        }
        chain = chain +> async
        return self
    }
    
    func always(closure : Void->Void)->Promise{
        alwaysClosure = closure
        return self
    }
    
    func error(closure : NSError?->Void)->Promise{
        errorClosure = closure
        fire()
        return self
    }
    
    func fire(){
        chain(info: 0) { (info, error) in
            if let always = self.alwaysClosure{
                always()
            }
            
            if error == nil{
                print("all task finished")
            }else{
                if let errorC = self.errorClosure{
                    errorC(error)
                }
            }
        }
    }
}

func firstly(body : Void->Void)->Promise{
    
    let starter: AsyncFunc = { _,complete in
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)) {
            body();
            complete(0,nil);
        }
    }

    return Promise(starter: starter)
}

func when(fstBody : (Void->Void), sndBody : (Void->Void)){
    let async1 : AsyncFunc = { _ , complete in
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)) {
            fstBody();
            complete(0,nil);
        }
    }
    
    let async2 : AsyncFunc = { _ , complete in
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0)) {
            sndBody();
            complete(0,nil);
        }
    }
    
    let async = async1 <> async2
    
    var finished = false
    
    async(info: 0) { (_, _) in
        finished = true
    }
    
    while finished == false {
        
    }
}

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        
        firstly { () in
            when({ () in
                print ("begin fst job")
                sleep(1)
                print("fst job in when finished")
                }, sndBody: { () in
                    print ("begin snd job")
                    sleep(5)
                    print("snd job in when finished")
            })
        }.then { (info) in
            print("second job")
            throw NSError(domain: "error", code: 0, userInfo: [:])
        }.then { (info) in
            print("third job")
        }.always { () in
            print("always block")
        }.error { (error) in
            print("error occurred")
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

