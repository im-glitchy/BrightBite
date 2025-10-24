//
//  CalendarService.swift
//  BrightBite
//
//  Created by Tuan Nguyen on 9/19/25.
//

import Foundation
import EventKit

class CalendarService {
    static let shared = CalendarService()

    private let eventStore = EKEventStore()

    private init() {}

    func requestAccess() async throws -> Bool {
        return try await eventStore.requestFullAccessToEvents()
    }

    func addAppointmentToCalendar(appointment: Appointment) async throws {
        
        let granted = try await requestAccess()
        guard granted else {
            throw CalendarError.accessDenied
        }

        
        let event = EKEvent(eventStore: eventStore)
        event.title = appointment.title

        
        if appointment.isAllDay {
            event.isAllDay = true
            
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: appointment.date)
            event.startDate = startOfDay
            event.endDate = calendar.date(byAdding: .day, value: 1, to: startOfDay)
        } else {
            event.isAllDay = false
            event.startDate = appointment.date
            event.endDate = appointment.date.addingTimeInterval(3600) 
        }

        if let location = appointment.location {
            event.location = location
        }

        if let notes = appointment.notes {
            event.notes = notes
        }

        
        let alarm = EKAlarm(relativeOffset: -86400) 
        event.addAlarm(alarm)

        
        event.calendar = eventStore.defaultCalendarForNewEvents

        try eventStore.save(event, span: .thisEvent)
    }

    func addAppointmentsToCalendar(_ appointments: [Appointment]) async throws {
        for appointment in appointments {
            try await addAppointmentToCalendar(appointment: appointment)
        }
    }
}

enum CalendarError: LocalizedError {
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .accessDenied:
            return "Calendar access denied. Please enable in Settings."
        }
    }
}
