import XCTest
@testable import UcapHutang

@MainActor
final class ReviewDetailViewModelTests: XCTestCase {
    private let satria = ContactRef(identifier: "contact-satria", displayName: "Satria Kans", phoneNumber: nil)

    private func personalDraft(name: String = "Satria", contactIdentifier: String? = nil) -> TransactionDraft {
        TransactionDraft(
            flow: .personal,
            type: .piutang,
            title: "Kopi",
            totalAmount: 20_000,
            participants: [TransactionParticipant(name: name, contactIdentifier: contactIdentifier, shareAmount: 20_000)],
            rawTranscript: "Satria ngutang 20 ribu beli kopi"
        )
    }

    private func splitDraft(friends: [(String, String?)], total: Int64 = 90_000) -> TransactionDraft {
        TransactionDraft(
            flow: .splitBill,
            type: .splitBill,
            title: "Makan malam",
            totalAmount: total,
            splitMethod: .equal,
            participants: friends.map { TransactionParticipant(name: $0.0, contactIdentifier: $0.1, shareAmount: 0) },
            rawTranscript: "makan malam"
        )
    }

    private func makeViewModel(
        seed draft: TransactionDraft?,
        contacts: FakeContactsProvider? = nil
    ) async throws -> (ReviewDetailViewModel, SpyTransactionRepository) {
        let provider = contacts ?? FakeContactsProvider()
        let spy = SpyTransactionRepository()
        if let draft {
            try await spy.base.saveDraft(draft)
        }
        let viewModel = ReviewDetailViewModel(
            draftID: draft?.id ?? UUID(),
            repository: spy,
            contacts: provider
        )
        await viewModel.load()
        return (viewModel, spy)
    }

    func testLoadShowsTheStoredDraftInsteadOfMockValues() async throws {
        let draft = personalDraft()
        let (viewModel, _) = try await makeViewModel(seed: draft)

        XCTAssertEqual(viewModel.loadState, .loaded)
        XCTAssertEqual(viewModel.draft?.title, "Kopi")
        XCTAssertEqual(viewModel.draft?.totalAmount, 20_000)
        XCTAssertEqual(viewModel.draft?.participants.first?.name, "Satria")
    }

    func testLoadOfMissingDraftShowsNotFound() async throws {
        let (viewModel, _) = try await makeViewModel(seed: nil)
        XCTAssertEqual(viewModel.loadState, .notFound)
    }

    func testSuggestionOnlyForAuthorizedAccessAndExactlyOneMatch() async throws {
        let draft = personalDraft(name: "Satria")

        let oneMatch = FakeContactsProvider(access: .authorized, contacts: [satria])
        let (vmOne, _) = try await makeViewModel(seed: draft, contacts: oneMatch)
        XCTAssertEqual(vmOne.draft?.participants[0].contactIdentifier, satria.identifier)
        XCTAssertEqual(vmOne.draft?.participants[0].name, satria.displayName)

        let twoMatches = FakeContactsProvider(access: .authorized, contacts: [
            satria,
            ContactRef(identifier: "contact-satria-2", displayName: "Satria Wijaya", phoneNumber: nil)
        ])
        let (vmTwo, _) = try await makeViewModel(seed: draft, contacts: twoMatches)
        XCTAssertNil(vmTwo.draft?.participants[0].contactIdentifier)

        let denied = FakeContactsProvider(access: .denied, contacts: [satria])
        let (vmDenied, _) = try await makeViewModel(seed: draft, contacts: denied)
        XCTAssertEqual(vmDenied.cardState(for: vmDenied.draft!.participants[0]), .unlinked)
    }

    func testPartialNameDoesNotAutoLinkWithoutAUniqueSafePrefix() async throws {
        let draft = personalDraft(name: "Sat")
        let provider = FakeContactsProvider(access: .authorized, contacts: [satria])

        let (viewModel, _) = try await makeViewModel(seed: draft, contacts: provider)

        XCTAssertNil(viewModel.draft?.participants.first?.contactIdentifier)
    }

    func testRequestingPickerWithDeniedAccessShowsContactsAlert() async throws {
        let draft = personalDraft()
        let (viewModel, _) = try await makeViewModel(seed: draft, contacts: FakeContactsProvider(access: .denied))
        let participantID = viewModel.draft!.participants[0].id

        await viewModel.requestPicker(.link(participantID: participantID, prefill: "Satria"))

        XCTAssertEqual(viewModel.alert, .contactsAccessRequired)
        XCTAssertNil(viewModel.pickerRequest)
    }

    func testRequestingPickerWithUndeterminedAccessAsksThenOpensPicker() async throws {
        let contacts = FakeContactsProvider(access: .notDetermined, accessAfterRequest: .authorized)
        let (viewModel, _) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]), contacts: contacts)

        await viewModel.requestPicker(.addParticipants)

        XCTAssertEqual(contacts.requestAccessCallCount, 1)
        XCTAssertEqual(viewModel.pickerRequest, .addParticipants)
        XCTAssertNil(viewModel.alert)
    }

    func testSavingWithUnlinkedPersonShowsIssuesAndNeverConfirms() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft())
        let participantID = viewModel.draft!.participants[0].id

        await viewModel.save()

        XCTAssertEqual(viewModel.alert, .incomplete(messages: ["Hubungkan setiap orang ke kontak sebelum menyimpan."]))
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        XCTAssertTrue(viewModel.showsRequiredMarker(for: participantID))
        XCTAssertFalse(viewModel.didFinish)
        let entries = try await spy.ledgerEntries()
        XCTAssertTrue(entries.isEmpty)
    }

    func testSavingLinkedDraftConfirmsAndFinishes() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft(contactIdentifier: "contact-satria"))

        await viewModel.save()

        XCTAssertEqual(spy.confirmDraftCallCount, 1)
        XCTAssertTrue(viewModel.didSave)
        XCTAssertTrue(viewModel.didFinish)
        let entries = try await spy.ledgerEntries()
        XCTAssertEqual(entries.count, 1)
    }

    func testLinkingAContactAlreadyUsedByAnotherParticipantShowsDuplicateAlert() async throws {
        let draft = splitDraft(friends: [("Satria Kans", "contact-satria"), ("Ari", nil)])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        let ari = viewModel.draft!.participants[1]

        viewModel.handlePicked([satria], for: .link(participantID: ari.id, prefill: "Ari"))

        XCTAssertEqual(viewModel.alert, .duplicateContact)
        XCTAssertNil(viewModel.draft!.participants[1].contactIdentifier)
        XCTAssertEqual(viewModel.draft!.participants[1].name, "Ari")
    }

    func testEqualSplitRecomputesWhenIncludesUserChanges() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari")])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
        XCTAssertEqual(viewModel.userShare, 30_000)

        viewModel.setIncludesUser(false)

        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [45_000, 45_000])
        XCTAssertEqual(viewModel.userShare, 0)
    }

    func testCustomSplitTotalFollowsTheShares() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari")])
        let (viewModel, _) = try await makeViewModel(seed: draft)

        viewModel.setSplitMethod(.custom)
        XCTAssertEqual(viewModel.draft!.totalAmount, 60_000)

        viewModel.setShare(participantID: viewModel.draft!.participants[1].id, amount: 40_000)
        XCTAssertEqual(viewModel.draft!.totalAmount, 70_000)

        viewModel.setTotalAmount(1)
        XCTAssertEqual(viewModel.draft!.totalAmount, 70_000, "Nominal is read-only in custom mode")
    }

    func testFlushPendingEditsSavesADirtyDraftWithoutConfirming() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setTitle("Kopi susu")
        await viewModel.flushPendingEdits()

        XCTAssertEqual(spy.saveDraftCallCount, 1)
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Kopi susu")
        XCTAssertEqual(stored?.status, .needsReview)
    }

    func testFlushPendingEditsDoesNothingWhenClean() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: personalDraft())

        await viewModel.flushPendingEdits()

        XCTAssertEqual(spy.saveDraftCallCount, 0)
    }

    func testDeleteRemovesTheDraftAndFinishes() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        await viewModel.delete()

        XCTAssertTrue(viewModel.didFinish)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored)
    }

    func testRemovingAParticipantRecomputesEqualShares() async throws {
        let draft = splitDraft(friends: [("Satria", "contact-satria"), ("Ari", "contact-ari"), ("Ros", "contact-ros")])
        let (viewModel, _) = try await makeViewModel(seed: draft)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [22_500, 22_500, 22_500])

        viewModel.removeParticipant(id: viewModel.draft!.participants[2].id)

        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
    }

    func testEditsAreSavedToTheDraftAutomaticallyWithoutConfirming() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)
        let participantID = viewModel.draft!.participants[0].id
        let newDate = draft.transactionDate.addingTimeInterval(3_600)

        viewModel.setTotalAmount(35_000)
        viewModel.setTitle("Bensin")
        viewModel.setTransactionDate(newDate)
        viewModel.handlePicked([satria], for: .link(participantID: participantID, prefill: "Satria"))
        await viewModel.awaitPendingAutosave()

        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.totalAmount, 35_000)
        XCTAssertEqual(stored?.title, "Bensin")
        XCTAssertEqual(stored?.transactionDate, newDate)
        XCTAssertEqual(stored?.participants.first?.name, "Satria Kans")
        XCTAssertEqual(stored?.participants.first?.contactIdentifier, "contact-satria")
        XCTAssertEqual(stored?.participants.first?.shareAmount, 35_000)
        XCTAssertEqual(stored?.status, .needsReview)
        XCTAssertEqual(spy.confirmDraftCallCount, 0)
        let entries = try await spy.ledgerEntries()
        XCTAssertTrue(entries.isEmpty)
        XCTAssertNil(viewModel.autosaveErrorMessage)
    }

    func testAutosaveFailureIsReportedWithoutAnAlert() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)
        spy.saveDraftError = RepositoryError.invalidAmount

        viewModel.setTitle("Bensin")
        await viewModel.flushPendingEdits()

        XCTAssertNil(viewModel.alert)
        XCTAssertEqual(
            viewModel.autosaveErrorMessage,
            "Perubahan belum berhasil disimpan otomatis. Coba ubah kembali atau buka ulang halaman ini."
        )
        let stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.title, "Kopi")
    }

    func testDeleteWaitsForPendingAutosaveAndDoesNotRecreateTheDraft() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setTitle("Kopi susu")
        await viewModel.delete()
        await viewModel.flushPendingEdits()

        XCTAssertTrue(viewModel.didFinish)
        XCTAssertEqual(spy.deleteDraftCallCount, 1)
        let stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored)
    }

    func testAddingAPersonByNameAddsAnUnlinkedParticipantAndRecomputesShares() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]))
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [45_000])

        viewModel.newParticipantName = "  Ari "
        await viewModel.addParticipantFromName()

        XCTAssertEqual(viewModel.draft!.participants.map(\.name), ["Satria", "Ari"])
        XCTAssertNil(viewModel.draft!.participants[1].contactIdentifier)
        XCTAssertEqual(viewModel.draft!.participants.map(\.shareAmount), [30_000, 30_000])
        XCTAssertEqual(viewModel.newParticipantName, "")
        await viewModel.awaitPendingAutosave()
        XCTAssertEqual(spy.saveDraftCallCount, 1)
    }

    func testAddingANameAlreadyInTheNoteShowsDuplicateAlert() async throws {
        let (viewModel, spy) = try await makeViewModel(seed: splitDraft(friends: [("Satria", "contact-satria")]))

        viewModel.newParticipantName = "satria"
        await viewModel.addParticipantFromName()

        XCTAssertEqual(viewModel.alert, .duplicateContact)
        XCTAssertEqual(viewModel.draft!.participants.count, 1)
        XCTAssertEqual(viewModel.newParticipantName, "satria")
        await viewModel.awaitPendingAutosave()
        XCTAssertEqual(spy.saveDraftCallCount, 0)
    }

    func testNotesAreSavedAndClearedWhenEmpty() async throws {
        let draft = personalDraft()
        let (viewModel, spy) = try await makeViewModel(seed: draft)

        viewModel.setNotes("Bayar minggu depan")
        await viewModel.awaitPendingAutosave()
        var stored = try await spy.draft(id: draft.id)
        XCTAssertEqual(stored?.notes, "Bayar minggu depan")

        viewModel.setNotes("")
        await viewModel.awaitPendingAutosave()
        stored = try await spy.draft(id: draft.id)
        XCTAssertNil(stored?.notes)
    }

    func testSaveStatusMessageFollowsContactLinks() async throws {
        let (viewModel, _) = try await makeViewModel(seed: personalDraft())
        XCTAssertEqual(viewModel.saveStatusMessage, "Hubungkan setiap orang ke kontak agar catatan dapat disimpan ke Riwayat.")

        let participantID = viewModel.draft!.participants[0].id
        viewModel.handlePicked([satria], for: .link(participantID: participantID, prefill: "Satria"))

        XCTAssertEqual(viewModel.saveStatusMessage, "Semua orang sudah terhubung. Catatan siap disimpan ke Riwayat.")
    }
}
