Pod::Spec.new do |spec|

  version = '1.1.7'

  spec.name = 'DalenysPayCardsRecognizer'
  spec.version = version
  spec.summary          = 'Bank card recognizer for mobile apps'
  spec.homepage         = 'https://pay.cards'
  spec.license          = { type: 'MIT', file: 'LICENSE.md' }
  spec.authors          = { 'PAY.CARDS' => 'support@pay.cards' }
  spec.social_media_url = 'https://twitter.com/Pay_Cards'
  spec.platform = :ios
  spec.requires_arc = true
  
  spec.source = {
#     :http => "https://github.com/therealmyluckyday/PayCards_iOS_Source/releases/download/1.1.7/PayCardsRecognizer.zip"
    :http => "https://www.myluckyday.fr/client/dalenys/ios/paycards/#{version}/PayCardsRecognizer.zip"
  }

  spec.ios.vendored_frameworks = "PayCardsRecognizer.xcframework"
  spec.ios.deployment_target = '9.0'

end
