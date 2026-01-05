pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common

Item {
    id: root

    readonly property var ambientItems: {
        const _version = PluginRunner.ambientVersion;
        return PluginRunner.getAmbientItems();
    }
    readonly property bool hasItems: ambientItems.length > 0

    implicitHeight: hasItems ? contentFlow.implicitHeight + 8 : 0
    visible: hasItems

    Behavior on implicitHeight {
        NumberAnimation { duration: 150; easing.type: Easing.OutCubic }
    }

    Flow {
        id: contentFlow
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.ambientItems

            delegate: AmbientItem {
                id: ambientItemDelegate
                required property var modelData
                required property int index

                item: modelData
                pluginId: modelData.pluginId ?? ""

                onDismissed: {
                    PluginRunner.handleAmbientAction(pluginId, item.id, "__dismiss__");
                    PluginRunner.removeAmbientItem(pluginId, item.id);
                }

                onActionClicked: (actionId) => {
                    PluginRunner.handleAmbientAction(pluginId, item.id, actionId);
                }
            }
        }
    }
}
