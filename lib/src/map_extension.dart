/// Destructure ALL keys into a new Map (handles null)
extension MapDestructuring<T> on Map<String, T>? {
  Map<String, T> destructure() =>
      this == null ? <String, T>{} : Map<String, T>.from(this!);
}
