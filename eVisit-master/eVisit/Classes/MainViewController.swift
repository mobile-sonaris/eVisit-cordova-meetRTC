//
//  MainViewController.swift
//  eVisit
//
//  Created by Sonnaris on 5/8/16.
//
//

import UIKit

class MainViewController: UIViewController {

    @IBOutlet weak var launchBtn: UIButton!
    override func viewDidLoad() {
        super.viewDidLoad()
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func launchBtnPressed(sender: AnyObject) {
        NSLog("This is test")
    }
}
