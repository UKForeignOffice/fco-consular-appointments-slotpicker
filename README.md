# fco-consular-appointments-slotpicker
Time and date selector for consular appointments, based on https://github.com/ministryofjustice/moj_slotpicker.

## Introduction
The FCO Consular appointments slot picker is an AngularJS version of the MOJ slotpicker which uses BookingBug's [Javascript SDK](https://github.com/BookingBug/bookingbug-angular) and [REST API](https://dev.bookingbug.com/rest_api) to retrieve availability data.

## Usage
The FCO slot picker is designed to be embedded as part of a BookingBug booking journey, however, by replacing usage of the TimeService and DayService with your own Angular service, the slot picker can work with an alternative data source. 

## Key Differences
- Refactored code to remove DOM mantipulation where possible as this is handled by AngularJS's two way data binding capabilities
- Refactored code to utilise BookingBug's AngularJS services for retrieving availability data
- Refactored code to interact with a BookingBug BasketItem when setting date/time
- Event binding has been removed and updated to use ng-click
- Days/month are no longer hard coded, instead moment.js is utilised
- Removed multiple time selection behaviour

