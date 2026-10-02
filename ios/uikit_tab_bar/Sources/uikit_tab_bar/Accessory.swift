import UIKit

/// Native content of the bottom accessory, described by `AccessorySpec`.
@available(iOS 26.0, *)
final class AccessoryContentView: UIView {
  var onTap: (() -> Void)?
  var onAction: ((String) -> Void)?
  var onEnvironment: ((UITabAccessory.Environment) -> Void)?

  private let iconView = UIImageView()
  private let titleLabel = UILabel()
  private let subtitleLabel = UILabel()
  private let buttons = UIStackView()
  private var spec: AccessorySpec?
  private var images: ImageStore?

  override init(frame: CGRect) {
    super.init(frame: frame)
    iconView.contentMode = .scaleAspectFit
    iconView.setContentHuggingPriority(.required, for: .horizontal)
    titleLabel.font = .preferredFont(forTextStyle: .subheadline)
    titleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.font = .preferredFont(forTextStyle: .caption1)
    subtitleLabel.adjustsFontForContentSizeCategory = true
    subtitleLabel.textColor = .secondaryLabel
    let labels = UIStackView(arrangedSubviews: [titleLabel, subtitleLabel])
    labels.axis = .vertical
    labels.spacing = 0
    buttons.axis = .horizontal
    buttons.spacing = 4
    let row = UIStackView(arrangedSubviews: [iconView, labels, buttons])
    row.axis = .horizontal
    row.alignment = .center
    row.spacing = 10
    row.translatesAutoresizingMaskIntoConstraints = false
    addSubview(row)
    NSLayoutConstraint.activate([
      row.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
      row.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10),
      row.centerYAnchor.constraint(equalTo: centerYAnchor),
      row.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: 2),
      iconView.widthAnchor.constraint(lessThanOrEqualToConstant: 28),
      iconView.heightAnchor.constraint(lessThanOrEqualToConstant: 28),
    ])
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
    isAccessibilityElement = false
    registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) {
      (self: AccessoryContentView, _: UITraitCollection) in
      self.layoutForEnvironment()
      self.onEnvironment?(self.traitCollection.tabAccessoryEnvironment)
    }
  }

  required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

  func configure(_ spec: AccessorySpec, images: ImageStore) {
    self.spec = spec
    self.images = images
    titleLabel.text = spec.title
    subtitleLabel.text = spec.subtitle
    iconView.image = images.image(spec.icon)
    iconView.isHidden = iconView.image == nil
    buttons.arrangedSubviews.forEach { $0.removeFromSuperview() }
    for action in spec.actions {
      let button = UIButton(type: .system)
      button.setImage(images.image(action.icon), for: .normal)
      button.accessibilityLabel = action.label
      button.accessibilityIdentifier = action.id
      button.addAction(UIAction { [weak self] _ in self?.onAction?(action.id) }, for: .touchUpInside)
      button.widthAnchor.constraint(equalToConstant: 36).isActive = true
      buttons.addArrangedSubview(button)
    }
    layoutForEnvironment()
  }

  /// Inline (next to the minimized bar) there is room for less.
  private func layoutForEnvironment() {
    let inline = traitCollection.tabAccessoryEnvironment == .inline
    subtitleLabel.isHidden = inline || (spec?.subtitle ?? "").isEmpty
    for (i, button) in buttons.arrangedSubviews.enumerated() {
      button.isHidden = inline && i > 0
    }
  }

  var environmentName: String {
    switch traitCollection.tabAccessoryEnvironment {
    case .regular: return "regular"
    case .inline: return "inline"
    default: return "none"
    }
  }

  @objc private func tapped() { onTap?() }
}
