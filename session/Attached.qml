import CryptoShark 1.0

import QtQuick 2.0
import QtQuick.Controls 1.2
import QtQuick.Controls.Styles 1.1
import QtQuick.Layouts 1.1

import "../components"

SplitView {
    id: attachedView

    property var agentService: null
    property alias threadsModel: threadsView.model
    property var models: null
    property var functionDialog: null

    property var currentModule: null
    property var currentFunction: null

    property var _functionsObservable: null

    function dispose() {
        log.dispose();
        modulesView.dispose();
        _updateFunctionsObservable(null);
    }

    onCurrentModuleChanged: {
        models.functions.load(currentModule !== null ? currentModule.id : -1);
    }

    onCurrentFunctionChanged: {
        var func = currentFunction;
        if (func) {
            agentService.disassemble(func.address, function (instructions) {
                disassembly.render(instructions);
            });
        }
    }

    orientation: Qt.Horizontal

    Item {
        width: sidebar.implicitWidth
        Layout.minimumWidth: 5

        ColumnLayout {
            id: sidebar
            spacing: 5

            anchors {
                fill: parent
                margins: 1
            }

            TableView {
                id: threadsView
                Layout.fillWidth: true

                TableViewColumn { role: "status"; title: ""; width: 20 }
                TableViewColumn { role: "id"; title: "Thread ID"; width: 63 }
                TableViewColumn { role: "tags"; title: "Tags"; width: 100 }
            }
            Row {
                Layout.fillWidth: true

                Button {
                    property string _action: !!threadsModel && threadsModel.get(threadsView.currentRow) && threadsModel.get(threadsView.currentRow).status === 'F' ? 'unfollow' : 'follow'
                    text: _action === 'follow' ? qsTr("Follow") : qsTr("Unfollow")
                    enabled: !!threadsModel && threadsModel.get(threadsView.currentRow) !== undefined
                    onClicked: {
                        var index = threadsView.currentRow;
                        if (_action === 'follow') {
                            threadsModel.setProperty(index, 'status', 'F');
                            agentService.follow(threadsModel.get(index).id);
                        } else {
                            threadsModel.setProperty(index, 'status', '');
                            agentService.unfollow(threadsModel.get(index).id);
                        }
                    }
                }
            }
            ComboBox {
                id: modulesView

                onCurrentIndexChanged: {
                    var currentId = model.data(currentIndex, 'id') || null;
                    if (currentId !== null) {
                        if (currentModule === null || currentModule.id !== currentId) {
                            currentModule = {
                                id: model.data(currentIndex, 'id'),
                                name: model.data(currentIndex, 'name'),
                                base: model.data(currentIndex, 'base')
                            };
                        }
                    } else if (currentModule !== null) {
                        currentModule = null;
                    }
                }

                model: models.modules
                textRole: 'name'
            }
            TableView {
                id: functionsView

                onCurrentRowChanged: {
                    var currentId = model.data(currentRow, 'id') || null;
                    if (currentId !== null) {
                        if (currentFunction === null || currentFunction.id !== currentId) {
                            var id = model.data(currentRow, 'id');
                            currentFunction = {
                                id: id,
                                name: model.data(currentRow, 'name'),
                                address: NativePointer.fromBaseAndOffset(currentModule.base, model.data(currentRow, 'offset')),
                                hasProbe: model.hasProbe(id)
                            };
                        }
                    } else if (currentFunction !== null) {
                        currentFunction = null;
                    }
                }

                onActivated: {
                    functionDialog.address = currentFunction.address;
                    functionDialog.open();
                }

                model: models.functions
                Layout.fillWidth: true
                Layout.fillHeight: true

                TableViewColumn { role: "status"; title: ""; width: 20 }
                TableViewColumn { role: "name"; title: "Function"; width: 83 }
                TableViewColumn { role: "calls"; title: "Calls"; width: 63 }
            }
            Row {
                Layout.fillWidth: true

                Button {
                    property string _action: !!currentFunction && currentFunction.hasProbe ? 'remove' : 'add'
                    text: _action === 'add' ? qsTr("Add Probe") : qsTr("Remove Probe")
                    enabled: !!currentFunction
                    onClicked: {
                        if (_action === 'add') {
                            models.functions.addProbe(currentFunction.id);
                        } else {
                            models.functions.removeProbe(currentFunction.id);
                        }
                        currentFunction = {
                            id: currentFunction.id,
                            name: currentFunction.name,
                            address: currentFunction.address,
                            hasProbe: models.functions.hasProbe(currentFunction.id)
                        };
                    }
                }
            }
        }
    }

    SplitView {
        orientation: Qt.Vertical

        DisassemblyView {
            id: disassembly
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        TextArea {
            id: log

            property var _lineLengths: []

            Component.onCompleted: {
                models.functions.logMessage.connect(_onLogMessage);
                functionDialog.rename.connect(_onRename);
            }

            function dispose() {
                functionDialog.rename.disconnect(_onRename);
                models.functions.logMessage.disconnect(_onLogMessage);
            }

            function _onLogMessage(func, message) {
                var lengthBefore = length;
                append("<font color=\"#ffffff\"><a href=\"" + func.address + "\">" + func.name + "</a>: </font><font color=\"#808080\">" + message + "</font>");
                var lengthAfter = length;
                var lineLength = lengthAfter - lengthBefore;
                _lineLengths.push(lineLength);
                if (_lineLengths.length === 11) {
                    var firstLineLength = _lineLengths.splice(0, 1)[0];
                    remove(0, firstLineLength);
                }
            }

            function _onRename(func, oldName, newName) {
                text = text.replace(new RegExp("(<a href=\"" + func.address + "\">.*?)\\b" + oldName + "\\b(.*?<\\/a>)", "g"), "$1" + newName + "$2");
            }

            onLinkActivated: {
                functionDialog.address = link;
                functionDialog.open();
            }

            Layout.fillWidth: true
            Layout.minimumHeight: 200
            style: TextAreaStyle {
                backgroundColor: "#060606"
            }
            font.family: "Lucida Console"
            textFormat: TextEdit.RichText
            wrapMode: TextEdit.NoWrap
            readOnly: true
        }
    }
}
