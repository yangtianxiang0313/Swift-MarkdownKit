Pod::Spec.new do |s|
  s.name         = 'XHSMarkdownKit'
  s.version      = '0.1.0'
  s.summary      = 'Model-first markdown rendering kit with scene runtime'
  s.description  = <<-DESC
    XHSMarkdownKit v2 uses a model-first architecture:
    - XHSMarkdownCore: canonical contract DTO/AST/render model/rewrite/diff
    - XHSMarkdownAdapterMarkdownn: markdownn (XYMarkdown) parser adapter
    - XHSMarkdownUIKit: scene renderer/container/animation runtime for iOS
    - XHSMarkdownKit/Full: convenience bundle (UIKit + AdapterMarkdownn)

    Core has no UIKit/XYMarkdown dependency; parser adapter is explicit.
  DESC

  s.homepage     = 'https://code.devops.xiaohongshu.com/yangtianxiang/xhsmarkdownkit'
  s.license      = { :type => 'MIT', :file => 'LICENSE' }
  s.author       = { '沃顿' => 'yangtianxiang@xiaohongshu.com' }
  s.source       = { :git => 'https://code.devops.xiaohongshu.com/yangtianxiang/XHSMarkdownKit.git', :tag => s.version.to_s }

  s.ios.deployment_target = '14.0'
  s.swift_version = '5.9'

  s.default_subspecs = ['UIKit']

  s.subspec 'Core' do |core|
    core.source_files = [
      'Sources/XHSMarkdownKit/Contract/**/*.swift',
      'Sources/XHSMarkdownKit/Markdown/Parser/MarkdownContractParser.swift'
    ]
  end

  s.subspec 'AdapterMarkdownn' do |adapter|
    adapter.source_files = 'Sources/XHSMarkdownKit/Markdown/Parser/XYMarkdown/**/*.swift'
    adapter.dependency 'XHSMarkdownKit/Core'
    adapter.dependency 'XYMarkdown', '~> 0.0.2'
  end

  s.subspec 'UIKit' do |uikit|
    uikit.source_files = [
      'Sources/XHSMarkdownKit/Core/**/*.swift',
      'Sources/XHSMarkdownKit/Extensions/**/*.swift',
      'Sources/XHSMarkdownKit/Markdown/Adapter/**/*.swift',
      'Sources/XHSMarkdownKit/Markdown/Delegate/**/*.swift',
      'Sources/XHSMarkdownKit/Markdown/Theme/**/*.swift',
      'Sources/XHSMarkdownKit/Public/**/*.swift'
    ]
    uikit.dependency 'XHSMarkdownKit/Core'
  end

  s.subspec 'Full' do |full|
    full.dependency 'XHSMarkdownKit/UIKit'
    full.dependency 'XHSMarkdownKit/AdapterMarkdownn'
  end

  s.test_spec 'Tests' do |ts|
    ts.source_files = 'Tests/**/*.swift'
    ts.resources = 'Tests/Fixtures/**/*'
  end
end
