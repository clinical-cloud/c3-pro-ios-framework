//
//  QuestionnaireController.swift
//  ResearchCHIP
//
//  Created by Pascal Pfiffner on 5/20/15.
//  Copyright (c) 2015 Boston Children's Hospital. All rights reserved.
//

import Foundation
import ResearchKit
import SMART

let CHIPQuestionnaireErrorKey = "CHIPQuestionnaireError"


/**
    Instances of this class can prepare questionnaires and get a callback when it's finished.
 */
public class QuestionnaireController: NSObject, ORKTaskViewControllerDelegate
{
	public final var questionnaire: Questionnaire?
	
	public final var whenFinished: ((viewController: ORKTaskViewController, reason: ORKTaskViewControllerFinishReason, error: NSError?) -> Void)?
	
	
	// MARK: - Questionnaire
	
	/**
	    Attempts to fulfill the promise, calling the callback when done, either with a task representing the
	    questionnaire or an error.
	 */
	func prepareQuestionnaire(callback: ((task: ORKTask?, error: NSError?) -> Void)) {
		if let questionnaire = questionnaire {
			let promise = QuestionnairePromise(questionnaire: questionnaire)
			promise.fulfill(nil) { errors in
				if let tsk = promise.task {
					callback(task: tsk, error: nil)
				}
				else if let errs = errors {
					if 1 == errs.count {
						callback(task: nil, error: errs[0])
					}
					else {
						let err = chip_genErrorQuestionnaire(errs.map() { $0.localizedDescription }.reduce("") { $0 + (!$0.isEmpty ? "\n" : "") + $1 })
						callback(task: nil, error: err)
					}
				}
				else {
					let err = chip_genErrorQuestionnaire("Unknown error creating a task from questionnaire")
					callback(task: nil, error: err)
				}
			}
		}
		else {
			let err = chip_genErrorQuestionnaire("I do not have a questionnaire just yet, cannot start")
			callback(task: nil, error: err)
		}
	}
	
	/**
	    Attempts to fulfill the promise, calling the callback when done, either with a task view controller already
	    prepared with the questionnaire task or an error.
	 */
	public func prepareQuestionnaireViewController(callback: ((viewController: ORKTaskViewController?, error: NSError?) -> Void)) {
		prepareQuestionnaire() { task, error in
			if let task = task {
				let viewController = ORKTaskViewController(task: task, taskRunUUID: nil)
				viewController.delegate = self
				callback(viewController: viewController, error: nil)
			}
			else {
				callback(viewController: nil, error: error)
			}
		}
	}
	
	/**
	    SYNCHRONOUSLY reads a questionnaire from the given URL. You only want to use this for debug purposes on
	    questionnaires included in the app bundle.
	 */
	final public func readQuestionnaireFromURL(url: NSURL, error: NSErrorPointer) -> Questionnaire? {
		if let jsondata = NSData(contentsOfURL: url, options: nil, error: error) {
			if let json = NSJSONSerialization.JSONObjectWithData(jsondata, options: nil, error: error) as? FHIRJSON {
				return Questionnaire(json: json)
			}
			else if nil != error && nil == error.memory {
				error.memory = chip_genErrorQuestionnaire("Failed to decode questionnaire JSON")
			}
		}
		else if nil != error && nil == error.memory {
			error.memory = chip_genErrorQuestionnaire("Failed to read questionnaire")
		}
		return nil
	}
	
	
	// MARK: - Task View Controller Delegate
	
	public func taskViewController(taskViewController: ORKTaskViewController, didFinishWithReason reason: ORKTaskViewControllerFinishReason, error: NSError?) {
		whenFinished?(viewController: taskViewController, reason: reason, error: error)
	}
}


/**
    Convenience function to create an NSError in our questionnaire error domain.
 */
public func chip_genErrorQuestionnaire(message: String, code: Int = 0) -> NSError {
	return NSError(domain: CHIPQuestionnaireErrorKey, code: code, userInfo: [NSLocalizedDescriptionKey: message])
}

