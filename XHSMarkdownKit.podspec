Pod::Spec.new do |s|
  s.name         = 'XHSMarkdownKit'
  s.version      = '0.1.0'
  s.summary      = 'Markdown rendering kit for XHS Apps'
  s.description  = <<-DESC
    基于 XYMarkdown 的 Markdown 渲染库。
    保留 XYMarkdown 作为解析层（底层 cmark），
    只重写渲染层（MarkupVisitor → NSAttributedString / UIView）。
    样式通过 Theme Token 配置，不依赖任何业务框架。
    
    主要特性：
    - 完整的 Markdown 节点覆盖（标题/列表/引用/代码块/表格/图片等）
    - 可扩展的渲染器协议（AttributedStringNodeRenderer / ViewNodeRenderer）
    - 样式 Token 化（MarkdownTheme）
    - 流式渲染支持（逐字渐入/增量更新）
    - 蓝链 AST 级改写（RichLinkRewriter）
    - Document 缓存
  DESC
  
  s.homepage     = 'https://code.devops.xiaohongshu.com/xhs-ios/XHSMarkdownKit'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { '沃顿' => 'yangtianxiang@xiaohongshu.com' }
  s.source       = { :git => 'https://code.devops.xiaohongshu.com/xhs-ios/XHSMarkdownKit.git', :tag => s.version.to_s }
  
  s.ios.deployment_target = '15.0'
  s.swift_version = '5.9'
  
  s.source_files = 'Sources/XHSMarkdownKit/**/*.swift'
  
  # 唯一外部依赖
  s.dependency 'XYMarkdown', '~> 0.0.2'
  
  # 测试 subspec
  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.swift'
    ts.resources = 'Tests/Fixtures/**/*'
  end
end
