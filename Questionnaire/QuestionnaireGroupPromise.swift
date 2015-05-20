//
//  QuestionnaireGroupPromise.swift
//  ResearchCHIP
//
//  Created by Pascal Pfiffner on 4/20/15.
//  Copyright (c) 2015 Boston Children's Hospital. All rights reserved.
//

import Foundation
import SMART
import ResearchKit


/**
	A promise that can fulfill a questionnaire question into an ORKQuestionStep.
 */
class QuestionnaireGroupPromise: QuestionnairePromiseProto
{
	/// The promises' group.
	let group: QuestionnaireGroup
	
	/// The group's steps, internally assigned after the promise has been successfully fulfilled.
	internal(set) var steps: [ORKStep]?
	
	init(group: QuestionnaireGroup) {
		self.group = group
	}
	
	
	// MARK: - Fulfilling
	
	/** Fulfill the promise.
	
	    Once the promise and its step promises have been successfully fulfilled, the `group` property will be assigned.
	
	    TODO: Implement `repeats` for repeating groups.
	    TODO: Respect "http://hl7.org/fhir/StructureDefinition/questionnaire-sdc-specialGroup" extensions
	
	    :param: callback The callback to be called when done; note that even when you get an error, some steps might
	        have successfully been allocated still, so don't throw everything away just because you receive errors
	 */
	func fulfill(parentRequirements: [ResultRequirement]?, callback: ((errors: [NSError]?) -> Void)) {
		var errors = [NSError]()
		var promises = [QuestionnairePromiseProto]()
		
		// create an introductory instruction step if we have a title or text
		var intro: ORKStep?
		let (title, text) = group.chip_bestTitleAndText()
		if (nil != title && !title!.isEmpty) || (nil != text && !text!.isEmpty) {
			intro = ORKInstructionStep(identifier: group.linkId ?? NSUUID().UUIDString)
			intro!.title = title
			intro!.text = text
		}
		
		// "enableWhen" requirements
		var requirements = parentRequirements ?? [ResultRequirement]()
		var error: NSError?
		if let myreqs = group.chip_enableQuestionnaireElementWhen(&error) {
			requirements.extend(myreqs)
		}
		else if nil != error {
			errors.append(error!)
		}
		
		// fulfill our subgroups or (!!) questions
		if let subgroups = group.group {
			for subgroup in subgroups {
				promises.append(QuestionnaireGroupPromise(group: subgroup))
			}
		}
		else if let questions = group.question {
			for question in questions {
				promises.append(QuestionnaireQuestionPromise(question: question))
			}
		}
		
		// fulfill our promises
		if count(promises) > 0 {
			let queueGroup = dispatch_group_create()
			for promise in promises {
				dispatch_group_enter(queueGroup)
				promise.fulfill(requirements) { berrors in
					if let err = berrors {
						errors.extend(err)
					}
					dispatch_group_leave(queueGroup)
				}
			}
			
			// on group notify, call the callback on the main queue
			dispatch_group_notify(queueGroup, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0)) {
				var steps = promises.filter() { return (nil != $0.steps) }.flatMap() { return $0.steps! }
				if let intr = intro {
					steps.insert(intr, atIndex: 0)
				}
				
				self.steps = steps
				dispatch_async(dispatch_get_main_queue()) {
					callback(errors: count(errors) > 0 ? errors : nil)
				}
			}
		}
		
		// no groups nor questions; maybe still some text
		else {
			if let intr = intro {
				steps = [intr]
			}
			callback(errors: errors)
		}
	}
	
	
	// MARK: - Printable
	
	var description: String {
		return NSString(format: "<QuestionnaireGroupPromise %p>", unsafeAddressOf(self)) as String
	}
}


extension QuestionnaireGroup
{
	func chip_bestTitleAndText() -> (String?, String?) {
		var ttl = title
		var txt = text
		
		if nil == ttl || nil == txt {
			let cDisplay = concept?.filter() { return nil != $0.display }.map() { return $0.display! }
			let cCodes = concept?.filter() { return nil != $0.code }.map() { return $0.code! }
			
			if nil == ttl {
				ttl = cDisplay?.first ?? cCodes?.first
			}
			else {
				txt = cDisplay?.first ?? cCodes?.first
			}
		}
		
		return (ttl?.chip_stripMultipleSpaces(), txt?.chip_stripMultipleSpaces())
	}
}
