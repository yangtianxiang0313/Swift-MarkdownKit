import Foundation
import UIKit

// MARK: - MarkdownImageView

/// Markdown 图片视图
public final class MarkdownImageView: UIView, FragmentConfigurable, StreamableContent, SimpleStreamableContent {

    public var totalLength: Int { 0 }
    
    // MARK: - UI Elements
    
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.clipsToBounds = true
        return iv
    }()
    
    private let placeholderView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        return view
    }()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    // MARK: - State
    
    private var currentSource: String = ""
    private var currentAlt: String = ""
    private var loadedImage: UIImage?
    private var theme: MarkdownTheme = .default
    
    // MARK: - Initialization
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        addSubview(placeholderView)
        addSubview(imageView)
        placeholderView.addSubview(activityIndicator)
    }
    
    // MARK: - Layout
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        placeholderView.frame = bounds
        placeholderView.layer.cornerRadius = theme.image.cornerRadius
        
        imageView.frame = bounds
        imageView.layer.cornerRadius = theme.image.cornerRadius
        
        activityIndicator.center = CGPoint(x: bounds.midX, y: bounds.midY)
    }
    
    public override func sizeThatFits(_ size: CGSize) -> CGSize {
        guard let image = loadedImage else {
            return CGSize(width: size.width, height: theme.image.placeholderHeight)
        }
        
        let maxWidth = min(size.width, theme.image.maxWidth)
        let aspectRatio = image.size.width / image.size.height
        
        let width = min(maxWidth, image.size.width)
        let height = width / aspectRatio
        
        return CGSize(width: width, height: height)
    }
    
    // MARK: - FragmentConfigurable
    
    public func configure(content: Any, theme: MarkdownTheme) {
        guard let imageContent = content as? ImageContent else { return }
        
        self.currentSource = imageContent.source
        self.currentAlt = imageContent.alt
        self.theme = theme
        
        placeholderView.backgroundColor = theme.image.placeholderColor
        
        loadImage(from: imageContent.source)
    }
    
    // MARK: - Image Loading
    
    private func loadImage(from source: String) {
        guard !source.isEmpty else { return }
        
        // 显示加载中
        placeholderView.isHidden = false
        imageView.isHidden = true
        activityIndicator.startAnimating()
        
        // 尝试从 URL 加载
        guard let url = URL(string: source) else {
            showPlaceholder()
            return
        }
        
        // 简单的图片加载（实际项目中应使用 SDWebImage 等库）
        URLSession.shared.dataTask(with: url) { [weak self] data, _, error in
            DispatchQueue.main.async {
                guard let self = self, self.currentSource == source else { return }
                
                if let data = data, let image = UIImage(data: data) {
                    self.loadedImage = image
                    self.imageView.image = image
                    self.imageView.isHidden = false
                    self.placeholderView.isHidden = true
                    self.activityIndicator.stopAnimating()
                    
                    // 通知需要重新布局
                    self.invalidateIntrinsicContentSize()
                    self.setNeedsLayout()
                } else {
                    self.showPlaceholder()
                }
            }
        }.resume()
    }
    
    private func showPlaceholder() {
        activityIndicator.stopAnimating()
        placeholderView.isHidden = false
        imageView.isHidden = true
    }
}
