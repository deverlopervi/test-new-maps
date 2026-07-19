import SwiftUI
import MapKit
import CoreLocation

struct MHMMapView: UIViewRepresentable {
    let hazards: [MHMHazard]
    let checkins: [MHMCheckin]
    let userCoordinate: CLLocationCoordinate2D?
    @Binding var centerCoordinate: CLLocationCoordinate2D

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.delegate = context.coordinator
        mapView.showsUserLocation = true
        mapView.pointOfInterestFilter = .includingAll
        mapView.mapType = .standard
        mapView.showsCompass = false
        mapView.showsScale = false
        mapView.tintColor = UIColor(hex: 0xF97316)

        if #available(iOS 16.0, *) {
            let configuration = MKStandardMapConfiguration(elevationStyle: .realistic)
            configuration.emphasisStyle = .muted
            configuration.pointOfInterestFilter = .includingAll
            mapView.preferredConfiguration = configuration
        }

        let region = MKCoordinateRegion(
            center: centerCoordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
        )
        mapView.setRegion(region, animated: false)
        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        context.coordinator.parent = self

        if shouldMoveMap(mapView) {
            let region = MKCoordinateRegion(
                center: centerCoordinate,
                span: mapView.region.span.latitudeDelta > 0 ? mapView.region.span : MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
            mapView.setRegion(region, animated: true)
        }

        let existing = mapView.annotations.filter { !($0 is MKUserLocation) }
        mapView.removeAnnotations(existing)
        mapView.addAnnotations(hazards.map { MHMAnnotation(hazard: $0) })
        mapView.addAnnotations(checkins.map { MHMAnnotation(checkin: $0) })
    }

    private func shouldMoveMap(_ mapView: MKMapView) -> Bool {
        let current = mapView.centerCoordinate
        let distance = CLLocation(latitude: current.latitude, longitude: current.longitude)
            .distance(from: CLLocation(latitude: centerCoordinate.latitude, longitude: centerCoordinate.longitude))
        return distance > 25
    }

    final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MHMMapView

        init(_ parent: MHMMapView) {
            self.parent = parent
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            parent.centerCoordinate = mapView.centerCoordinate
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard let annotation = annotation as? MHMAnnotation else { return nil }
            let identifier = annotation.kind.rawValue
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: identifier) as? MKMarkerAnnotationView
                ?? MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: identifier)
            view.annotation = annotation
            view.canShowCallout = true
            view.displayPriority = annotation.kind == .hazard ? .required : .defaultHigh
            view.markerTintColor = annotation.tintColor
            view.glyphTintColor = .white
            view.titleVisibility = .adaptive
            view.subtitleVisibility = .adaptive
            view.glyphImage = UIImage(systemName: annotation.glyphName)
            view.rightCalloutAccessoryView = UIImageView(image: UIImage(systemName: "chevron.right.circle.fill"))
            return view
        }
    }
}

final class MHMAnnotation: NSObject, MKAnnotation {
    enum Kind: String {
        case hazard
        case checkin
    }

    let id: Int
    let kind: Kind
    let coordinate: CLLocationCoordinate2D
    let title: String?
    let subtitle: String?
    let glyphName: String
    let tintColor: UIColor

    init(hazard: MHMHazard) {
        self.id = hazard.id
        self.kind = .hazard
        self.coordinate = hazard.coordinate.clLocation
        self.title = hazard.title
        self.subtitle = [hazard.type, hazard.severity].compactMap { $0 }.joined(separator: " • ")
        self.glyphName = MHMAnnotation.glyphName(for: hazard)
        self.tintColor = MHMAnnotation.tintColor(for: hazard)
    }

    init(checkin: MHMCheckin) {
        self.id = checkin.id
        self.kind = .checkin
        // Dòng 121: Thay thế checkin.coordinate.clLocation bằng struct tọa độ gốc flat mới[cite: 4]
        self.coordinate = CLLocationCoordinate2D(latitude: checkin.lat, longitude: checkin.lng)
        self.title = checkin.title
        // Dòng 124: Đổi từ checkin.note thành checkin.description cho khớp backend[cite: 4]
        self.subtitle = checkin.description
        self.glyphName = "camera.fill"
        self.tintColor = UIColor(hex: 0xF97316)
    }

    private static func normalizedText(for hazard: MHMHazard) -> String {
        [hazard.type, hazard.severity, hazard.title]
            .compactMap { $0 }
            .joined(separator: " ")
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
    }

    private static func glyphName(for hazard: MHMHazard) -> String {
        let text = normalizedText(for: hazard)
        if text.contains("tai nan") { return "car.side.fill" }
        if text.contains("tac duong") { return "road.lanes" }
        if text.contains("ngap") || text.contains("mua") { return "cloud.heavyrain.fill" }
        if text.contains("sat lo") { return "mountain.2.fill" }
        if text.contains("bao") || text.contains("gio") { return "wind" }
        if text.contains("cap cuu") || text.contains("cuu thuong") { return "cross.case.fill" }
        if text.contains("hoa hoan") { return "flame.fill" }
        if text.contains("sos") { return "sos" }
        if text.contains("cuu ho") { return "wrench.and.screwdriver.fill" }
        return "exclamationmark.triangle.fill"
    }

    private static func tintColor(for hazard: MHMHazard) -> UIColor {
        let text = normalizedText(for: hazard)
        if text.contains("ngap") || text.contains("mua") { return UIColor(hex: 0x2F80ED) }
        if text.contains("cuu ho") { return UIColor(hex: 0xF59E0B) }
        if text.contains("tac duong") { return UIColor(hex: 0xF97316) }
        if text.contains("sos") || text.contains("cap cuu") || text.contains("hoa hoan") { return UIColor(hex: 0xDC2626) }
        return UIColor(hex: 0xEF4444)
    }
}

private extension UIColor {
    convenience init(hex: UInt, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}