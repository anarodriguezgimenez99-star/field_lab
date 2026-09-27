import SwiftUI
import UIKit

struct CloudSyncSettingsView: View {
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(FieldLanguage.preferenceKey) private var languageCode = FieldLanguage.spanish.rawValue

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: appModel.cloudAccountState.symbol)
                            .font(.title2)
                            .foregroundStyle(appModel.cloudAccountState == .available ? Color.green : Color(uiColor: .secondaryLabel))
                            .frame(width: 30, alignment: .leading)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(L10n.text(appModel.cloudAccountState.title))
                                .font(.headline)
                            Text(appModel.cloudAccountDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section(L10n.text("Tus datos")) {
                    Label(L10n.text("Biblioteca local disponible sin conexión"), systemImage: "iphone.and.arrow.forward")
                    Label(
                        L10n.text(appModel.cloudAccountState == .available ? "Cuenta iCloud disponible" : "Sincronización iCloud pendiente"),
                        systemImage: appModel.cloudAccountState == .available ? "checkmark.icloud" : "icloud.slash"
                    )
                    Label(
                        L10n.text(appModel.shareImportsConfigured ? "Guardar desde el menú Compartir" : "Compartir pendiente de configuración"),
                        systemImage: "square.and.arrow.down"
                    )
                }

                Section(L10n.text("Language")) {
                    Picker(L10n.text("Language"), selection: $languageCode) {
                        ForEach(FieldLanguage.allCases) { language in
                            Text(language.name).tag(language.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityLabel(L10n.text("Language"))
                }

                if appModel.importedReferenceCount > 0 || appModel.importError != nil {
                    Section(L10n.text("Compartir con FIELD")) {
                        if appModel.importedReferenceCount > 0 {
                            Label(L10n.format("%d referencias importadas desde Compartir", appModel.importedReferenceCount), systemImage: "square.and.arrow.down")
                        }
                        if let importError = appModel.importError {
                            Label(importError, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        Button(L10n.text("Revisar importaciones"), systemImage: "arrow.clockwise") {
                            appModel.processPendingImports()
                        }
                    }
                }

                if appModel.cloudKitContainerIdentifier == nil || !appModel.shareImportsConfigured {
                    Section {
                        if appModel.cloudKitContainerIdentifier == nil {
                            Text(L10n.text("Copia Apps/Config/FieldICloud.local.xcconfig.example como FieldICloud.local.xcconfig, sustituye los IDs de ejemplo y activa iCloud + CloudKit en los targets de iPhone y Mac. La biblioteca local seguirá disponible mientras tanto."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if !appModel.shareImportsConfigured {
                            Text(L10n.text("Para importar desde Compartir, registra FIELD_APP_GROUP_ID y activa el mismo App Group en la app de iPhone y en FIELDShare."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text(L10n.text("Configuración pendiente"))
                    }
                }

                Section {
                    Button(L10n.text("Comprobar ahora"), systemImage: "arrow.clockwise") {
                        appModel.refreshCloudAccountState()
                    }
                }
            }
            .navigationTitle(L10n.text("Ajustes"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("Hecho")) { dismiss() }
                }
            }
        }
    }
}
