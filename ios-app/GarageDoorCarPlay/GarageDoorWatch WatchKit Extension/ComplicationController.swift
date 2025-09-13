import ClockKit
import SwiftUI

class ComplicationController: NSObject, CLKComplicationDataSource {
    
    // MARK: - Complication Configuration
    
    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "garage-doors",
                displayName: "Garage Doors",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .circularSmall,
                    .extraLarge,
                    .graphicCorner,
                    .graphicBezel,
                    .graphicCircular,
                    .graphicRectangular
                ]
            )
        ]
        
        handler(descriptors)
    }
    
    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do any necessary work to support these newly shared complication descriptors
    }
    
    // MARK: - Timeline Configuration
    
    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Call the handler with the last entry date you can currently provide or nil if you can't support future timelines
        handler(Date().addingTimeInterval(24 * 60 * 60)) // 24 hours from now
    }
    
    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Call the handler with your desired behavior when the device is locked
        handler(.showOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Get current status from UserDefaults or other persistent storage
        let door1Status = UserDefaults.standard.string(forKey: "door1Status") ?? "Unknown"
        let door2Status = UserDefaults.standard.string(forKey: "door2Status") ?? "Unknown"
        
        let template = createTemplate(for: complication.family, door1Status: door1Status, door2Status: door2Status)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        
        handler(entry)
    }
    
    func getTimelineEntries(for complication: CLKComplication, after date: Date, limit: Int, withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void) {
        // Call the handler with the timeline entries after the given date
        handler(nil)
    }
    
    // MARK: - Sample Templates
    
    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(for: complication.family, door1Status: "Closed", door2Status: "Open")
        handler(template)
    }
    
    // MARK: - Template Creation
    
    private func createTemplate(for family: CLKComplicationFamily, door1Status: String, door2Status: String) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "🚪")
            )
            
        case .modularLarge:
            return CLKComplicationTemplateModularLargeStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Garage Doors"),
                body1TextProvider: CLKSimpleTextProvider(text: "Door 1: \(door1Status)"),
                body2TextProvider: CLKSimpleTextProvider(text: "Door 2: \(door2Status)")
            )
            
        case .utilitarianSmall:
            return CLKComplicationTemplateUtilitarianSmallFlat(
                textProvider: CLKSimpleTextProvider(text: "🚪")
            )
            
        case .utilitarianLarge:
            return CLKComplicationTemplateUtilitarianLargeFlat(
                textProvider: CLKSimpleTextProvider(text: "Garage: \(door1Status)/\(door2Status)")
            )
            
        case .circularSmall:
            return CLKComplicationTemplateCircularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "🚪")
            )
            
        case .extraLarge:
            return CLKComplicationTemplateExtraLargeSimpleText(
                textProvider: CLKSimpleTextProvider(text: "🚪")
            )
            
        case .graphicCorner:
            return CLKComplicationTemplateGraphicCornerTextImage(
                textProvider: CLKSimpleTextProvider(text: "Garage"),
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "car.garage") ?? UIImage())
            )
            
        case .graphicBezel:
            let circularTemplate = CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "car.garage") ?? UIImage())
            )
            return CLKComplicationTemplateGraphicBezelCircularText(
                circularTemplate: circularTemplate,
                textProvider: CLKSimpleTextProvider(text: "\(door1Status)/\(door2Status)")
            )
            
        case .graphicCircular:
            return CLKComplicationTemplateGraphicCircularImage(
                imageProvider: CLKFullColorImageProvider(fullColorImage: UIImage(systemName: "car.garage") ?? UIImage())
            )
            
        case .graphicRectangular:
            return CLKComplicationTemplateGraphicRectangularStandardBody(
                headerTextProvider: CLKSimpleTextProvider(text: "Garage Doors"),
                body1TextProvider: CLKSimpleTextProvider(text: "Door 1: \(door1Status)"),
                body2TextProvider: CLKSimpleTextProvider(text: "Door 2: \(door2Status)")
            )
            
        @unknown default:
            return CLKComplicationTemplateModularSmallSimpleText(
                textProvider: CLKSimpleTextProvider(text: "🚪")
            )
        }
    }
}