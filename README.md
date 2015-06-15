# fco-consular-appointments-slotpicker
Time and date selector for consular appointments, based on https://github.com/ministryofjustice/moj_slotpicker.

## Introduction
The FCO Consular appointments slot picker is an AngularJS version of the MOJ slotpicker which uses BookingBug's [Javascript SDK][1] and [REST API][2] to retrieve availability data.

## Usage
The FCO slot picker is designed to be embedded as part of a BookingBug booking journey, however, by replacing usage of the TimeService and DayService with your own Angular service, the slot picker can work with an alternative data source. 

[1][https://github.com/BookingBug/bookingbug-angular]
[2][https://dev.bookingbug.com/rest_api]

