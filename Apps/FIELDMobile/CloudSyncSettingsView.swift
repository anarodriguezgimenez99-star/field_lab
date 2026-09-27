import SwiftUI
import UIKit

struct CloudSyncSettingsView: View {
    @EnvironmentObject private var appModel: MobileAppModel
    @Environment(\.dismiss) private var dismiss

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
                            Text(appModel.cloudAccountState.title)
                                .font(.headline)
                            Text(appModel.cloudAccountDetail)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(.vertical, 8)
                }

                Section("Tus datos") {
                    Label("Biblioteca local disponible sin conexión", systemImage: "iphone.and.arrow.forward")
                    Label(
                        appModel.cloudAccountState == .available ? "Cuenta iCloud disponible" : "Sincronización iCloud pendiente",
                        systemImage: appModel.cloudAccountState == .available ? "checkmark.icloud" : "icloud.slash"
                    )
                    Label(
                        appModel.shareImportsConfigured ? "Guardar desde el menú Compartir" : "Compartir pendiente de configuración",
                        systemImage: "square.and.arrow.down"
                    )
                }

                if appModel.importedReferenceCount > 0 || appModel.importError != nil {
                    Section("Compartir con FIELD") {
                        if appModel.importedReferenceCount > 0 {
                            Label("\(appModel.importedReferenceCount) referencias importadas desde Compartir", systemImage: "square.and.arrow.down")
                        }
                        if let importError = appModel.importError {
                            Label(importError, systemImage: "exclamationmark.triangle")
                                .foregroundStyle(.red)
                        }
                        Button("Revisar importaciones", systemImage: "arrow.clockwise") {
                            appModel.processPendingImports()
                        }
                    }
                }

                if appModel.cloudKitContainerIdentifier == nil || !appModel.shareImportsConfigured {
                    Section {
                        if appModel.cloudKitContainerIdentifier == nil {
                            Text("Copia Apps/Config/FieldICloud.local.xcconfig.example como FieldICloud.local.xcconfig, sustituye los IDs de ejemplo y activa iCloud + CloudKit en los targets de iPhone y Mac. La biblioteca local seguirá disponible mientras tanto.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if !appModel.shareImportsConfigured {
                            Text("Para importar desde Compartir, registra FIELD_APP_GROUP_ID y activa el mismo App Group en la app de iPhone y en FIELDShare.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Configuración pendiente")
                    }
                }

                Section {
                    Button("Comprobar ahora", systemImage: "arrow.clockwise") {
                        appModel.refreshCloudAccountState()
                    }
                }
            }
            .navigationTitle("Ajustes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Hecho") { dismiss() }
                }
            }
        }
    }
}
