/* This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0. If a copy of the MPL was not distributed with this file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import Storage

func telemetry(action action: String, props: [String: String]?) {
/* TODO: GROWTH:
    #if NO_FABRIC
        return
    #else
        if MixpanelManager.sharedInstance.getMainInstance() == nil {
            return
        }
        let mixpanel = Mixpanel.mainInstance()
        mixpanel.track(event: action, properties: props)
    #endif
 */
}

func debugNoteIfNotMainThread() {
    assert(NSThread.isMainThread(), "Func not for off-main use. This crashes in debug.")
}

class Debug_FuncProfiler {
    let startTime:CFAbsoluteTime
    init() {
        startTime = CFAbsoluteTimeGetCurrent()
    }

    func stop() -> CFAbsoluteTime {
        return CFAbsoluteTimeGetCurrent() - startTime
    }
}

func postAsyncToBackground(delay:Double = 0, closure:()->()) {
    postAsyncToQueue(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), delay: delay, closure: closure)
}

func postAsyncToMain(delay:Double = 0, closure:()->()) {
    postAsyncToQueue(dispatch_get_main_queue(), delay: delay, closure: closure)
}

func postAsyncToQueue(queue: dispatch_queue_t, delay:Double = 0, closure:()->()) {
    if delay == 0 {
        /*
         * per docs: passing DISPATCH_TIME_NOW as the "when" parameter is supported, but not as
         * optimal as calling dispatch_async() instead.
         */
        dispatch_async(queue, closure)
    }
    else {
        dispatch_after(
            dispatch_time(
                DISPATCH_TIME_NOW,
                Int64(delay * Double(NSEC_PER_SEC))
            ),
            queue, closure)
    }
}


// Lookup time is O(maxDicts)
// Very basic implementation of a recent item collection class, stored as groups of items in dictionaries, oldest items are deleted as blocks of items since their entire containing dictionary is deleted.
class FifoDict {
    var fifoArrayOfDicts: [NSMutableDictionary] = []
    let maxDicts = 5
    let maxItemsPerDict = 50

    // the url key is a combination of urls, the main doc url, and the url being checked
    func addItem(key: String, value: AnyObject?) {
        if fifoArrayOfDicts.count > maxItemsPerDict {
            fifoArrayOfDicts.removeFirst()
        }

        if fifoArrayOfDicts.last == nil || fifoArrayOfDicts.last?.count > maxItemsPerDict {
            fifoArrayOfDicts.append(NSMutableDictionary())
        }

        if let lastDict = fifoArrayOfDicts.last {
            if value == nil {
                lastDict[key] = NSNull()
            } else {
                lastDict[key] = value
            }
        }
    }

    func getItem(key: String) -> AnyObject?? {
        for dict in fifoArrayOfDicts {
            if let item = dict[key] {
                return item
            }
        }
        return nil
    }
}

class InsetLabel: UILabel {
    var leftInset = CGFloat(0)
    var rightInset = CGFloat(0)
    var topInset = CGFloat(0)
    var bottomInset = CGFloat(0)

    override func drawTextInRect(rect: CGRect) {
        super.drawTextInRect(UIEdgeInsetsInsetRect(rect, UIEdgeInsets(top: topInset, left: leftInset, bottom: bottomInset, right: rightInset)))
    }
}


extension String {
    func regexReplacePattern(pattern:String,  with:String) -> String {
        let regex = try! NSRegularExpression(pattern:pattern, options: [])
        return regex.stringByReplacingMatchesInString(self, options: [], range: NSMakeRange(0, self.characters.count), withTemplate: with)
    }
}

extension NSURL {
    func hostWithGenericSubdomainPrefixRemoved() -> String? {
        return host != nil ? stripGenericSubdomainPrefixFromUrl(host!) : nil
    }
}

// Firefox has uses urls of the form  http://localhost:6571/errors/error.html?url=http%3A//news.google.ca/ to populate the browser history, and load+redirect using GCDWebServer
func stripLocalhostWebServer(url: String?) -> String {
    guard let url = url else { return "" }
#if !TEST // TODO fix up the fact lots of code isn't available in the test suite, this is just an additional check, so for testing the rest of the code will work fine
    if !url.startsWith(WebServer.sharedInstance.base) {
        return url
    }
#endif
    // I think the ones prefixed with the following are the only ones of concern. There is also about/sessionrestore urls, not sure if we need to look at those
    let token = "errors/error.html?url="
    let range = url.rangeOfString(token)
    if let range = range {
        return url.substringFromIndex(range.endIndex)
    } else {
        return url
    }
}

func stripGenericSubdomainPrefixFromUrl(url: String) -> String {
    return url.regexReplacePattern("^(m\\.|www\\.|mobile\\.)", with:"");
}

func addSkipBackupAttributeToItemAtURL(url:NSURL) {
    let fileManager = NSFileManager.defaultManager()
    #if DEBUG
    assert(fileManager.fileExistsAtPath(url.path!))
    #endif

    do {
        try url.setResourceValue(true, forKey: NSURLIsExcludedFromBackupKey)
    } catch {
        print("Error excluding \(url.lastPathComponent) from backup \(error)")
    }
}


func getBestFavicon(favicons: [Favicon]) -> Favicon? {
    if favicons.count < 1 {
        return nil
    }

    var best: Favicon? = nil
    for icon in favicons {
        if best == nil {
            best = icon
            continue
        }

        if icon.type.isPreferredTo(best!.type) || best!.url.endsWith(".svg") {
            best = icon
        } else if let width = icon.width, let widthBest = best!.width where width > 0 && width > widthBest {
            best = icon
        } else {
            // the last number in the url is likely a size (...72x72.png), use as a best-guess as to which icon comes next
            func extractNumberFromUrl(url: String) -> Int? {
                var end = (url as NSString).lastPathComponent
                end = end.regexReplacePattern("\\D", with: " ")
                var parts = end.componentsSeparatedByString(" ")
                for i in (0..<parts.count).reverse() {
                    if let result = Int(parts[i]) {
                        return result
                    }
                }
                return nil
            }

            if let nextNum = extractNumberFromUrl(icon.url), bestNum = extractNumberFromUrl(best!.url) {
                if nextNum > bestNum {
                    best = icon
                }
            }
        }
    }
    return best
}

#if DEBUG
func report_memory() {
    let MACH_TASK_BASIC_INFO_COUNT = (sizeof(mach_task_basic_info_data_t) / sizeof(natural_t))
    let name   = mach_task_self_
    let flavor = task_flavor_t(MACH_TASK_BASIC_INFO)
    var size   = mach_msg_type_number_t(MACH_TASK_BASIC_INFO_COUNT)
    let infoPointer = UnsafeMutablePointer<mach_task_basic_info>.alloc(1)
    let kerr = task_info(name, flavor, UnsafeMutablePointer(infoPointer), &size)
    let info = infoPointer.move()
    infoPointer.dealloc(1)
    if kerr == KERN_SUCCESS {
        print("Memory in use (in MB): \(info.resident_size/1000000)")
    } else {
        let errorString = String(CString: mach_error_string(kerr), encoding: NSASCIIStringEncoding)
        print(errorString ?? "Error: couldn't parse error string")
    }
}
#endif
