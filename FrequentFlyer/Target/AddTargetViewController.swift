import UIKit

class AddTargetViewController: UIViewController {
    @IBOutlet weak var targetNameTextField: UITextField?
    @IBOutlet weak var concourseURLTextField: UITextField?
    @IBOutlet weak var addTargetButton: UIButton?

    weak var addTargetDelegate: AddTargetDelegate?
    var authMethodsService: AuthMethodsService?
    var unauthenticatedTokenService: UnauthenticatedTokenService?

    class var storyboardIdentifier: String { get { return "AddTarget" } }
    class var presentAuthCredentialsSegueId: String { get { return "PresentAuthCredentials" } }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Add Target"

        targetNameTextField?.delegate = self
        concourseURLTextField?.delegate = self

        addTargetButton?.enabled = false
    }

    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == AddTargetViewController.presentAuthCredentialsSegueId {
            if let authCredentialsViewController = segue.destinationViewController as? AuthCredentialsViewController {
                authCredentialsViewController.authCredentialsDelegate = self

                let basicAuthTokenService = BasicAuthTokenService()
                basicAuthTokenService.httpClient = HTTPClient()
                basicAuthTokenService.tokenDataDeserializer = TokenDataDeserializer()
                authCredentialsViewController.basicAuthTokenService = basicAuthTokenService

                authCredentialsViewController.concourseURLString = concourseURLTextField?.text
            }
        }
    }

    @IBAction func onAddTargetTapped() {
        guard let authMethodsService = authMethodsService else { return }
        guard let unauthenticatedTokenService = unauthenticatedTokenService else { return }
        guard let targetName = targetNameTextField?.text else { return }
        guard let concourseURL = concourseURLTextField?.text else { return }

        authMethodsService.getMethods(forTeamName: "main", concourseURL: concourseURL) { authMethods, error in
            if authMethods == nil || authMethods!.count == 0 {
                unauthenticatedTokenService.getUnauthenticatedToken(forTeamName: "main",
                                                                    concourseURL: concourseURL) { token, error in
                                                                        guard let token = token else {
                                                                            let alert = UIAlertController(title: "Authorization Failed",
                                                                                                          message: error?.details,
                                                                                                          preferredStyle: .Alert)
                                                                            alert.addAction(UIAlertAction(title: "OK", style: .Default, handler: nil))
                                                                            dispatch_async(dispatch_get_main_queue()) {
                                                                                self.presentViewController(alert, animated: true, completion: nil)
                                                                            }

                                                                            return
                                                                        }

                                                                        let newTarget = Target(name: targetName,
                                                                                               api: concourseURL,
                                                                                               teamName: "main",
                                                                                               token: token)
                                                                        self.addTargetDelegate?.onTargetAdded(newTarget)
                }
            } else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.performSegueWithIdentifier(AddTargetViewController.presentAuthCredentialsSegueId, sender: nil)
                }
            }
        }
    }
}

extension AddTargetViewController: UITextFieldDelegate {
    func textField(textField: UITextField, shouldChangeCharactersInRange range: NSRange, replacementString string: String) -> Bool {
        if textField === targetNameTextField {
            if string != "" {
                addTargetButton?.enabled = concourseURLTextField?.text != ""
            } else {
                addTargetButton?.enabled = false
            }
        } else if textField === concourseURLTextField {
            if string != "" {
                addTargetButton?.enabled = targetNameTextField?.text != ""
            } else {
                addTargetButton?.enabled = false
            }
        }

        return true
    }

    func textFieldShouldClear(textField: UITextField) -> Bool {
        addTargetButton?.enabled = false
        return true
    }
}

extension AddTargetViewController: AuthCredentialsDelegate {
    func onCredentialsEntered(token: Token) {
        guard let targetName = targetNameTextField?.text else { return }
        guard let concourseURL = concourseURLTextField?.text else { return }
        guard let addTargetDelegate = addTargetDelegate else { return }

        dispatch_async(dispatch_get_main_queue()) {
            self.dismissViewControllerAnimated(true) {
                let target = Target(name: targetName,
                                    api: concourseURL,
                                    teamName: "main",
                                    token: token)
                addTargetDelegate.onTargetAdded(target)
            }
        }
    }
}
