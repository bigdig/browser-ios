/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

import Foundation
import UIKit
import Shared


/// App Settings Screen (triggered by tapping the 'Gear' in the Tab Tray Controller)
class AppSettingsTableViewController: SettingsTableViewController {
    private let SectionHeaderIdentifier = "SectionHeaderIdentifier"

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = Strings.Settings
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: Strings.Done,
            style: UIBarButtonItemStyle.Done,
            target: navigationController, action: #selector(SettingsNavigationController.SELdone))
        navigationItem.leftBarButtonItem?.accessibilityIdentifier = "AppSettingsTableViewController.navigationItem.leftBarButtonItem"

        tableView.accessibilityIdentifier = "AppSettingsTableViewController.tableView"
    }

    override func generateSettings() -> [SettingSection] {
        var settings = [SettingSection]()

        let accountDebugSettings: [Setting]
        accountDebugSettings = []

        let prefs = profile.prefs
        var generalSettings = [
            SearchSetting(settings: self),
            BoolSetting(prefs: prefs, prefKey: "blockPopups", defaultValue: true,
                titleText: Strings.BlockPopupWindows),
            BoolSetting(prefs: prefs, prefKey: "saveLogins", defaultValue: true,
                titleText: Strings.Save_Logins),
        ]

        let accountChinaSyncSetting: [Setting]
        let locale = NSLocale.currentLocale()
        if locale.localeIdentifier != "zh_CN" {
            accountChinaSyncSetting = []
        } else {
            accountChinaSyncSetting = [
                // Show China sync service setting:
//                ChinaSyncServiceSetting(settings: self)
            ]
        }
        
        settings += [
            SettingSection(title: nil, children: [
//                // Without a Firefox Account:
//                ConnectSetting(settings: self),
//                // With a Firefox Account:
//                AccountStatusSetting(settings: self),
//                SyncNowSetting(settings: self)
            ] + accountChinaSyncSetting + accountDebugSettings)]

        settings += [ SettingSection(title: NSAttributedString(string: Strings.General), children: generalSettings)]

        var privacySettings = [Setting]()

        privacySettings.append(ClearPrivateDataSetting(settings: self))

        privacySettings += [
            BoolSetting(prefs: prefs,
                prefKey: "settings.closePrivateTabs",
                defaultValue: false,
                titleText: Strings.Close_Private_Tabs,
                statusText:Strings.When_Leaving_Private_Browsing)
        ]

        privacySettings += [
            PrivacyPolicySetting()
        ]

        return settings
    }

    override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
#if !BRAVE
        if !profile.hasAccount() {
            let headerView = tableView.dequeueReusableHeaderFooterViewWithIdentifier(SectionHeaderIdentifier) as! SettingsTableSectionHeaderFooterView
            let sectionSetting = settings[section]
            headerView.titleLabel.text = sectionSetting.title?.string

            switch section {
                // Hide the bottom border for the Sign In to Firefox value prop
                case 1:
                    headerView.titleAlignment = .Top
                    headerView.titleLabel.numberOfLines = 0
                    headerView.showBottomBorder = false
                    headerView.titleLabel.snp_updateConstraints { make in
                        make.right.equalTo(headerView).offset(-50)
                    }

                // Hide the top border for the General section header when the user is not signed in.
                case 2:
                    headerView.showTopBorder = false
                default:
                    return super.tableView(tableView, viewForHeaderInSection: section)
            }
            return headerView
        }
#endif
        return super.tableView(tableView, viewForHeaderInSection: section)
    }
}
