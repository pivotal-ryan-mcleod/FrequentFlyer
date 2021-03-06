import XCTest
import Quick
import Nimble
import Fleet
import RxSwift
@testable import FrequentFlyer

class ConcourseEntryViewControllerSpec: QuickSpec {
    class MockTeamListService: TeamListService {
        var capturedConcourseURL: String?
        var teamListSubject = PublishSubject<[String]>()

        override func getTeams(forConcourseWithURL concourseURL: String) -> Observable<[String]> {
            capturedConcourseURL = concourseURL
            return teamListSubject
        }
    }

    override func spec() {
        describe("ConcourseEntryViewController") {
            var subject: ConcourseEntryViewController!
            var mockTeamListService: MockTeamListService!
            var mockUserTextInputPageOperator: UserTextInputPageOperator!

            var mockTeamsViewController: TeamsViewController!

            beforeEach {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)

                mockTeamsViewController = try! storyboard.mockIdentifier(TeamsViewController.storyboardIdentifier, usingMockFor: TeamsViewController.self)

                subject = storyboard.instantiateViewController(withIdentifier: ConcourseEntryViewController.storyboardIdentifier) as! ConcourseEntryViewController

                mockTeamListService = MockTeamListService()
                subject.teamListService = mockTeamListService

                mockUserTextInputPageOperator = UserTextInputPageOperator()
                subject.userTextInputPageOperator = mockUserTextInputPageOperator
            }

            describe("After the view loads") {
                var navigationController: UINavigationController!

                beforeEach {
                    navigationController = UINavigationController(rootViewController: subject)
                    Fleet.setAsAppWindowRoot(navigationController)
                }

                it("sets a blank title") {
                    expect(subject.title).to(equal(""))
                }

                it("sets up its Concourse URL entry text field") {
                    guard let concourseURLEntryTextField = subject.concourseURLEntryField else {
                        fail("Failed to create Concourse URL entry text field")
                        return
                    }

                    expect(concourseURLEntryTextField.textField?.autocorrectionType).to(equal(UITextAutocorrectionType.no))
                    expect(concourseURLEntryTextField.textField?.keyboardType).to(equal(UIKeyboardType.URL))
                }

                it("sets itself as the UserTextInputPageOperator's delegate") {
                    expect(mockUserTextInputPageOperator.delegate).to(beIdenticalTo(subject))
                }

                describe("As a UserTextInputPageDelegate") {
                    it("returns text fields") {
                        expect(subject.textFields.count).to(equal(1))
                        expect(subject.textFields[0]).to(beIdenticalTo(subject?.concourseURLEntryField?.textField))
                    }

                    it("returns a page view") {
                        expect(subject.pageView).to(beIdenticalTo(subject.view))
                    }

                    it("returns a page scrolls view") {
                        expect(subject.pageScrollView).to(beIdenticalTo(subject.scrollView))
                    }
                }

                describe("Availability of the 'Submit' button") {
                    it("is disabled just after the view is loaded") {
                        expect(subject.submitButton?.isEnabled).to(beFalse())
                    }

                    describe("When the 'Concourse URL' field has text") {
                        beforeEach {
                            try! subject.concourseURLEntryField?.textField?.enter(text: "turtle url")
                        }

                        it("enables the button") {
                            expect(subject.submitButton!.isEnabled).to(beTrue())
                        }

                        describe("When the 'Concourse URL' field is cleared") {
                            beforeEach {
                                try! subject.concourseURLEntryField?.textField?.startEditing()
                                try! subject.concourseURLEntryField?.textField?.backspaceAll()
                                try! subject.concourseURLEntryField?.textField?.stopEditing()
                            }

                            it("disables the button") {
                                expect(subject.submitButton!.isEnabled).to(beFalse())
                            }
                        }
                    }
                }

                describe("Entering a Concourse URL without 'http://' or 'https://' and hitting 'Submit'") {
                    beforeEach {
                        try! subject.concourseURLEntryField?.textField?.enter(text: "partial-concourse.com")

                        try! subject.submitButton?.tap()
                    }

                    it("disables the button") {
                        expect(subject.submitButton?.isEnabled).toEventually(beFalse())
                    }

                    it("prepends your request with `https://` and uses it to make a call to the team list service") {
                        expect(mockTeamListService.capturedConcourseURL).to(equal("https://partial-concourse.com"))
                    }

                    describe("When the team list service call resolves with some team names") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onNext(["turtle_team", "crab_team", "puppy_team"])
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("makes a call to the team list service using the Concourse URL") {
                            expect(mockTeamListService.capturedConcourseURL).to(equal("https://partial-concourse.com"))
                        }

                        it("presents the \(TeamsViewController.self)") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockTeamsViewController))
                            expect(mockTeamsViewController.concourseURLString).toEventually(equal("https://partial-concourse.com"))
                            expect(mockTeamsViewController.teams).toEventually(equal(["turtle_team", "crab_team", "puppy_team"]))
                        }
                    }

                    describe("When the team list service call resolves with no teams") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onNext([])
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("presents an alert informing the user that there appear to be no teams") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.title).toEventually(equal("No Teams"))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message).toEventually(equal("We could find your Concourse instance, but it has no teams to show you."))
                        }

                        it("enables the button") {
                            expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                        }
                    }

                    describe("When the team list service call resolves with an error") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onError(BasicError(details: ""))
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("presents an alert informing the user of the build that was triggered") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.title).toEventually(equal("Error"))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message).toEventually(equal("Could not connect to a Concourse at the given URL."))
                        }

                        it("enables the button") {
                            expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                        }
                    }
                }

                describe("Entering a valid Concourse URL and hitting 'Submit'") {
                    beforeEach {
                        try! subject.concourseURLEntryField?.textField?.enter(text: "https://concourse.com")

                        try! subject.submitButton?.tap()
                    }

                    it("disables the button") {
                        expect(subject.submitButton?.isEnabled).toEventually(beFalse())
                    }

                    it("uses the entered Concourse URL to make a call to the team list service") {
                        expect(mockTeamListService.capturedConcourseURL).to(equal("https://concourse.com"))
                    }

                    describe("When the team list service call resolves with some team names") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onNext(["turtle_team", "crab_team", "puppy_team"])
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("makes a call to the team list service using the Concourse URL") {
                            expect(mockTeamListService.capturedConcourseURL).to(equal("https://concourse.com"))
                        }

                        it("presents the \(TeamsViewController.self)") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beIdenticalTo(mockTeamsViewController))
                            expect(mockTeamsViewController.concourseURLString).toEventually(equal("https://concourse.com"))
                            expect(mockTeamsViewController.teams).toEventually(equal(["turtle_team", "crab_team", "puppy_team"]))
                        }
                    }

                    describe("When the team list service call resolves with no teams") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onNext([])
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("presents an alert informing the user that there appear to be no teams") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.title).toEventually(equal("No Teams"))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message).toEventually(equal("We could find your Concourse instance, but it has no teams to show you."))
                        }

                        it("enables the button") {
                            expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                        }
                    }

                    describe("When the team list service call resolves with an error") {
                        beforeEach {
                            mockTeamListService.teamListSubject.onError(BasicError(details: ""))
                            mockTeamListService.teamListSubject.onCompleted()
                        }

                        it("presents an alert informing the user of the build that was triggered") {
                            expect(Fleet.getApplicationScreen()?.topmostViewController).toEventually(beAKindOf(UIAlertController.self))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.title).toEventually(equal("Error"))
                            expect((Fleet.getApplicationScreen()?.topmostViewController as? UIAlertController)?.message).toEventually(equal("Could not connect to a Concourse at the given URL."))
                        }

                        it("enables the button") {
                            expect(subject.submitButton?.isEnabled).toEventually(beTrue())
                        }
                    }
                }
            }
        }
    }
}
