System Service Permissions
==========================

These classes provide facilities to prompt the user to allow certain system services, such as access to HealthKit, the device's current location, notifications and others.
These are represented as `SystemService` enums, some of which have associated values.

**Note** that as of iOS 10, you must provide a short explanation for `NSHealthShareUsageDescription`, if you use HealthKit, and `NSMotionUsageDescription`, if you use CoreMotion, in your app's _Info.plist_.


### Module Interface

#### IN
- Array of `SystemService` instances

#### OUT
- `SystemPermissionStepViewController`, for use during a ResarchKit task, giving the user the option to give access to desired services.
- `SystemPermissionTableViewController`, a UITableView subclass, giving the user the option to give access to desired services.


System Services
---------------

**Before consenting**, the desired system services can be specified, in which case an additional step will be added to the consenting task, prompting the user to give access to some system services. Here's an example requesting access to:

- Local Notifications
    + associated with the notification categories that we will register
- CoreMotion
- Current location when using the app
    + associated with a text explaining why it is needed; localize this text!
- HealthKit
    + associated with characteristics to read and quantities to read and write

```swift
// the notification actions we want to perform
let category = UIMutableUserNotificationCategory()
category.identifier = "delayable"
category.setActions(...)

// the HealthKit data we want to access
let hkCRead = Set<HKCharacteristicType>([
    HKCharacteristicType.characteristicTypeForIdentifier(
        HKCharacteristicTypeIdentifierBiologicalSex)!,
    HKCharacteristicType.characteristicTypeForIdentifier(
        HKCharacteristicTypeIdentifierDateOfBirth)!,
])
let hkQRead = Set<HKQuantityType>([
    HKQuantityType.quantityTypeForIdentifier(
        HKQuantityTypeIdentifierHeight)!,
    HKQuantityType.quantityTypeForIdentifier(
        HKQuantityTypeIdentifierBodyMass)!,
])
let hkTypes = HealthKitTypes(
    readCharacteristics: hkCRead,
    readQuantities: hkQRead,
    writeQuantities: Set())

// set options on our consent controller BEFORE starting consent
consentController.options.wantedServicePermissions = [
    SystemService.localNotifications(Set(arrayLiteral: category)),
    SystemService.coreMotion,
    SystemService.geoLocationWhenUsing("Access to your current location..."),
    SystemService.healthKit(hkTypes),
]

// now you could present the consent task view controller
let vc = consentController.eligibilityStatusViewController(...)
...
```

You can use `SystemServicePermissioner` to query for permissions.
Instantiate a permissioner, then ask it for the current permission state like so:

```swift
let permissioner = SystemServicePermissioner()
if permissioner.hasGeoLocationPermissions(always: false) {
	// do geolocation, e.g. using `Geocoder`
}

// or
if permissioner.hasPermission(for: .coreMotion) {
	// you have access to motion activity
}
```


### Permissions View Controller

During consenting you use the `SystemPermissionStep` step, which will automatically show a `SystemPermissionStepViewController` when running the task.
You can also use `SystemPermissionTableViewController`, configured with the services you'd like using its `services` property, and show it from anywhere inside the app.
This is usually done from a profile page so the user may re-run the permissioning.
