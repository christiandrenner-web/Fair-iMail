// CoreDataService.swift
// Sicherheitsanforderungen (Audit S3):
//   – shouldMigrateStoreAutomatically VOR loadPersistentStores setzen
//   – kein fatalError in Production (App würde abstürzen statt sauber zu degradieren)
//   – .completeFileProtection und Backup-Ausschluss auf der Store-Datei
//   – Hinweis: CoreDataService hat noch keinen Aufrufer im Projekt (Offline-Cache
//     ist geplant). Diese Klasse ist korrekt vorbereitet, aber noch nicht integriert.
import CoreData
import Foundation
import Logging

final class CoreDataService {
    static let shared = CoreDataService()
    private let logger = Logger(label: "io.imailsecure.coredata")

    /// Nil wenn der Store nicht geladen werden konnte (kein fatalError).
    private(set) var loadError: Error?

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "iMailSecure")

        // Store-Beschreibung BEFORE loadPersistentStores konfigurieren
        if let description = container.persistentStoreDescriptions.first {
            // Migration automatisch durchführen
            description.shouldMigrateStoreAutomatically    = true
            description.shouldInferMappingModelAutomatically = true

            // Vollständiger Dateischutz: Store verschlüsselt wenn Gerät gesperrt
            description.setOption(
                FileProtectionType.complete as NSObject,
                forKey: NSPersistentStoreFileProtectionKey)
        }

        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error {
                // Fehler loggen, nicht abstürzen – App degradiert gracefully
                self?.logger.error("CoreData-Ladefehler: \(error.localizedDescription)")
                self?.loadError = error
                return
            }

            // Backup-Ausschluss auf Store-Datei setzen
            if let storeURL = storeDescription.url {
                var rv = URLResourceValues()
                rv.isExcludedFromBackup = true
                var mutableURL = storeURL
                try? mutableURL.setResourceValues(rv)
            }
        }

        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()

    var context: NSManagedObjectContext { persistentContainer.viewContext }

    /// Gibt an ob der Store verfügbar ist (nil = OK, non-nil = Fehler).
    var isAvailable: Bool { loadError == nil }

    func save() throws {
        guard context.hasChanges else { return }
        try context.save()
    }

    func newBackgroundContext() -> NSManagedObjectContext {
        persistentContainer.newBackgroundContext()
    }
}
