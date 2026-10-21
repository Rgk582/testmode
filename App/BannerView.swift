import UIKit

/// A dark banner that slides in from the top edge, shows text, then slides away.
final class BannerView: UIView {
    private let label = UILabel()
    private var hideWork: DispatchWorkItem?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.1, alpha: 0.96)
        isUserInteractionEnabled = false
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    func show(lines: [String], in host: UIView, seconds: TimeInterval = 6) {
        hideWork?.cancel()
        layer.removeAllAnimations()
        removeFromSuperview()

        label.text = lines.joined(separator: "\n")
        translatesAutoresizingMaskIntoConstraints = false
        host.addSubview(self)
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            topAnchor.constraint(equalTo: host.topAnchor),
            label.topAnchor.constraint(equalTo: host.safeAreaLayoutGuide.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12),
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
        ])
        host.layoutIfNeeded()

        transform = CGAffineTransform(translationX: 0, y: -bounds.height)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            self.transform = .identity
        }

        let work = DispatchWorkItem { [weak self] in self?.hide() }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }

    private func hide() {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn, animations: {
            self.transform = CGAffineTransform(translationX: 0, y: -self.bounds.height)
        }, completion: { _ in
            self.removeFromSuperview()
        })
    }
}
