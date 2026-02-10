import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
  public typealias LiveDeliveryData = ContentState

  public struct ContentState: Codable, Hashable { }
  
  var id = UUID()
}

let sharedDefault = UserDefaults(suiteName: "group.powerboards-prototype")!

struct MeetingWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            // // Lock screen/banner UI
            
            let name = sharedDefault.string(forKey: context.attributes.prefixedKey("name"))!
            let startDateSeconds = sharedDefault.double(forKey: context.attributes.prefixedKey("startDate")) / 1000;
            let primaryImage = sharedDefault.string(forKey: context.attributes.prefixedKey("primaryImage"))!

            let timeIntervalSinceNow = startDateSeconds - Date().timeIntervalSince1970

            let uiImagePrimary = UIImage(contentsOfFile: primaryImage)!

            HStack {
                VStack {
                    Spacer()
                    Image(uiImage: uiImagePrimary)
                        .renderingMode(.template)
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.green)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(
                        Date(
                            timeIntervalSinceNow: timeIntervalSinceNow
                        ),
                        style: .timer
                    )
                    .fontWeight(.bold)
                    .foregroundStyle(.green)

                    Text(name)
                        .font(.title)
                        .fontWeight(.bold)
                        .lineLimit(1)
                }
            }
            // .activityBackgroundTint(Color.cyan)
            // .activitySystemActionForegroundColor(Color.black)
        } dynamicIsland: { context in
            let name = sharedDefault.string(forKey: context.attributes.prefixedKey("name"))!
            let isAudioOn = sharedDefault.bool(forKey: context.attributes.prefixedKey("isAudioOn"));
            let isCameraOn = sharedDefault.bool(forKey: context.attributes.prefixedKey("isCameraOn"));
            let startDateSeconds = sharedDefault.double(forKey: context.attributes.prefixedKey("startDate")) / 1000;
            let primaryImage = sharedDefault.string(forKey: context.attributes.prefixedKey("primaryImage"))!
            let hangupImage = sharedDefault.string(forKey: context.attributes.prefixedKey("hangupImage"))!
            let speakerImage = sharedDefault.string(forKey: context.attributes.prefixedKey("speakerImage"))!
            let audioImage = sharedDefault.string(forKey: context.attributes.prefixedKey("audioImage"))!
            let videoImage = sharedDefault.string(forKey: context.attributes.prefixedKey("videoImage"))!
            
            let timeIntervalSinceNow = startDateSeconds - Date().timeIntervalSince1970

            let uiImagePrimary = UIImage(contentsOfFile: primaryImage)!
            let uiImageHangup = UIImage(contentsOfFile: hangupImage)!
            let uiImageSpeaker = UIImage(contentsOfFile: speakerImage)!
            let uiImageAudio = UIImage(contentsOfFile: audioImage)!
            let uiImageVideo = UIImage(contentsOfFile: videoImage)!
            
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {}
                DynamicIslandExpandedRegion(.trailing) {}
                DynamicIslandExpandedRegion(.center) {}
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        HStack {
                            Image(uiImage: uiImagePrimary)
                                .renderingMode(.template)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(
                                    Date(
                                        timeIntervalSinceNow: timeIntervalSinceNow
                                    ),
                                    style: .timer
                                )
                                .fontWeight(.bold)
                                .foregroundStyle(.green)
                                
                                Text(name)
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                
                            }
                        }
                        
                        HStack(spacing: 20) {
                            Link(destination: URL(string: "power://hangup")!) {
                                Image(uiImage: uiImageSpeaker)
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.vertical, 10).padding(.horizontal, 10)
                                    .foregroundColor(.white)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.gray.opacity(0.3))
                            )
                            
                            Link(destination: URL(string: "power://audio/\(!isAudioOn)")!) {
                                Image(uiImage: uiImageAudio)
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.vertical, 10).padding(.horizontal, 10)
                                    .foregroundColor(isAudioOn ? .black : .white)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isAudioOn ? Color.white : Color.gray.opacity(0.3))
                            )
                            
                            Link(destination: URL(string: "power://camera/\(!isCameraOn)")!) {
                                Image(uiImage: uiImageVideo)
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.vertical, 10).padding(.horizontal, 10)
                                    .foregroundColor(isCameraOn ? .black : .white)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(isCameraOn ? Color.white : Color.gray.opacity(0.3))
                            )
                            
                            Link(destination: URL(string: "power://hangup")!) {
                                Image(uiImage: uiImageHangup)
                                    .renderingMode(.template)
                                    .resizable()
                                    .frame(width: 30, height: 30)
                                    .padding(.vertical, 10).padding(.horizontal, 10)
                                    .foregroundColor(.white)
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 25)
                                    .fill(Color.red)
                            )
                        }
                    }
                    .offset(y:-15)
                }
            } compactLeading: {
                Image(uiImage: uiImagePrimary)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.green)
            } compactTrailing: {
                Text(
                    Date(
                        timeIntervalSinceNow: timeIntervalSinceNow
                    ),
                    style: .timer
                )
                .frame(maxWidth: 41)    //value important for layout
                .font(.footnote)
                .fontWeight(.bold)
                .foregroundStyle(.green)
            } minimal: {
                Image(uiImage: uiImagePrimary)
                    .renderingMode(.template)
                    .resizable()
                    .frame(width: 25, height: 25)
                    .foregroundColor(.green)
            }
        }
    }
}

extension LiveActivitiesAppAttributes {
  func prefixedKey(_ key: String) -> String {
    return "\(id)_\(key)"
  }
}

//#Preview("Notification", as: .content, using: MeetingWidgetAttributes.preview) {
//  MeetingWidgetLiveActivity()
//} contentStates: {
//   MeetingWidgetAttributes.ContentState.smiley
//   MeetingWidgetAttributes.ContentState.starEyes
//}
