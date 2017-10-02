import UIKit
import Spots
import Sugar

class JSONController: UIViewController {

  lazy var scrollView = UIScrollView()

  lazy var titleLabel = UILabel().then { label in
    label.text = "JSON"
    label.font = UIFont(name: "HelveticaNeue-Medium", size: 20)!
    label.textColor = UIColor(red:0.86, green:0.86, blue:0.86, alpha:1)
    label.textAlignment = .center
    label.numberOfLines = 0
    label.sizeToFit()
  }

  lazy var textView = UITextView().then {
    $0.font = UIFont(name: "Menlo", size: 13)
  }

  lazy var submitButton: UIButton = { [unowned self] in
    let button = UIButton()
    button.addTarget(self, action: #selector(submitButtonDidPress(_:)), for: .touchUpInside)
    button.setTitle("Build", for: UIControlState())

    return button
    }()

  lazy var tapGesture: UITapGestureRecognizer = { [weak self] in
    let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
    return tapGesture
  }()

  override func viewDidLoad() {
    super.viewDidLoad()

    view.backgroundColor = UIColor.white
    view.addGestureRecognizer(tapGesture)

    navigationItem.backBarButtonItem = UIBarButtonItem(title: nil, style: .plain, target: nil, action: nil)

    [titleLabel, textView, submitButton].forEach { view.addSubview($0) }

    submitButton.setTitleColor(UIColor.gray, for: UIControlState())
    submitButton.layer.borderColor = UIColor.gray.cgColor
    submitButton.layer.borderWidth = 1.5
    submitButton.layer.cornerRadius = 7.5

    textView.layer.borderColor = UIColor.lightGray.cgColor
    textView.layer.borderWidth = 1.0
    textView.layer.cornerRadius = 7.5

    let bundlePath = Bundle.main.path(forResource: "components", ofType: "json")
    let data = FileManager.default.contents(atPath: bundlePath!)
    let json = NSString(data: data!, encoding:String.Encoding.utf8.rawValue) as! String

    textView.text = json

    setupFrames()
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    setupFrames()
  }

  // MARK: Action methods

  func submitButtonDidPress(_ button: UIButton? = nil) {
    if let data = textView.text.data(using: String.Encoding.utf8) {

      do {
        let json = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String : AnyObject]
        if let json = json {
          let spots: [Spotable] = Parser.parse(json)
          let controller = Controller(spots: spots)
          navigationController?.pushViewController(controller, animated: true)
        }
      } catch {
        let alertController = UIAlertController(title: "Error", message: "Unable to resolve JSON", preferredStyle: .alert)
        let doneAction = UIAlertAction(title: "Okay", style: .default, handler: nil)
        alertController.addAction(doneAction)
        present(alertController, animated: true, completion: nil)
      }
    }
  }

  func backgroundTapped(_ gesture: UITapGestureRecognizer) {
    textView.resignFirstResponder()
  }

  // MARK - Configuration

  func setupFrames() {
    let totalSize = UIScreen.main.bounds


    if [.portrait, .portraitUpsideDown].contains(UIApplication.shared.statusBarOrientation) {
      titleLabel.frame.origin = CGPoint(x: (totalSize.width - titleLabel.width) / 2, y: 90)
      textView.frame = CGRect(x: 25, y: titleLabel.frame.maxY + 25, width: totalSize.width - 25 * 2, height: 350)
      submitButton.frame = CGRect(x: 50, y: textView.frame.maxY + 50, width: totalSize.width - 100, height: 50)
    } else {
      titleLabel.frame.origin = CGPoint(x: (totalSize.width - titleLabel.width) / 2, y: 50)
      textView.frame = CGRect(x: 25, y: titleLabel.frame.maxY + 25, width: totalSize.width - 25 * 2, height: 150)
      submitButton.frame = CGRect(x: 50, y: textView.frame.maxY + 50, width: totalSize.width - 100, height: 50)
    }
  }
}