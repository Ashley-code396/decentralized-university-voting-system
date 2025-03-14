/*
/// Module: university
module university::university;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions
#[allow(duplicate_alias)]
module university::election {
    use sui::object::{Self, UID};
    use sui::tx_context::{Self, TxContext};
    use sui::event;

    // Struct to represent a student's voting NFT
    public struct StudentVoterNFT has key, store {
        id: UID,
        name: vector<u8>,
        description: vector<u8>,
        image_url: vector<u8>,
        student_id: u64,
        voting_power: u64,
        is_graduated: bool,
        last_updated: u64, // Added field
    }

    // Struct to represent a candidate
    public struct Candidate has key, store {
        id: UID,
        student_id: u64,
        name: vector<u8>,
        campaign_promises: vector<u8>,
        vote_count: u64,
    }

    // Struct to represent a vote
    public struct Vote has key, store {
        id: UID,
        voter_id: u64,
        candidate_id: u64,
    }

    // Struct to store election results
    public struct ElectionResult has key, store {
        id: UID,
        candidate_id: u64,
        total_votes: u64,
    }

    // Events
    public struct StudentVoterNFTCreated has copy, drop {
        student_id: u64,
        voting_power: u64,
    }

    public struct VotingPowerUpdated has copy, drop {
        student_id: u64,
        new_voting_power: u64,
    }

    public struct StudentGraduated has copy, drop {
        student_id: u64,
    }

    public struct CandidateRegistered has copy, drop {
        student_id: u64,
        name: vector<u8>,
    }

    public struct VoteCast has copy, drop {
        voter_id: u64,
        candidate_id: u64,
    }

    public struct ElectionResultsTallied has copy, drop {
        candidate_id: u64,
        total_votes: u64,
    }

    // Function to create a new student voting NFT
    public fun create_student_voting_nft(student_id: u64, ctx: &mut TxContext): StudentVoterNFT {
        let voter_nft = StudentVoterNFT {
            id: object::new(ctx),
            name: b"University Voter ID",
            description: b"This is a unique voter ID for university elections.",
            image_url: b"https://i.ibb.co/h1KD5V3D/profile-image-erp.jpg",
            student_id,
            voting_power: 1,
            is_graduated: false,
            last_updated: tx_context::epoch(ctx), // Initialize with the current epoch timestamp
        };

        event::emit(StudentVoterNFTCreated {
            student_id,
            voting_power: 1,
        });

        voter_nft
    }

    // Helper function to convert u64 to vector<u8> (string representation)
    fun u64_to_vector(value: u64): vector<u8> {
        let mut result: vector<u8> = vector::empty();
        let mut temp = value;

        if (temp == 0) {
            vector::push_back(&mut result, 48); // ASCII value for '0'
            return result
        };

        while (temp > 0) {
            let digit = (temp % 10) as u8;
            vector::push_back(&mut result, 48 + digit); // Convert digit to ASCII
            temp = temp / 10;
        };

        // Reverse the vector to get the correct order
        let mut reversed: vector<u8> = vector::empty();
        let mut i = vector::length(&result);
        while (i > 0) {
            i = i - 1;
            vector::push_back(&mut reversed, *vector::borrow(&result, i));
        };

        reversed
    }

    // Function to update voting power yearly (simulate academic progression)
    public fun update_voting_power(voter_nft: &mut StudentVoterNFT, current_time: u64) {
        assert!(!voter_nft.is_graduated, 0); // Ensure student is active

        let time_elapsed = current_time - voter_nft.last_updated;
        if (time_elapsed >= 365 * 24 * 60 * 60) { // 365 days in seconds
            voter_nft.voting_power = voter_nft.voting_power + 1;
            voter_nft.last_updated = current_time;

            // Update NFT description
            let mut new_description = b"Your voting power is now: ";
            let voting_power_str = u64_to_vector(voter_nft.voting_power);
            vector::append(&mut new_description, voting_power_str);
            voter_nft.description = new_description;

            event::emit(VotingPowerUpdated {
                student_id: voter_nft.student_id,
                new_voting_power: voter_nft.voting_power,
            });
        }
    }

    // Function to mark a student as graduated (deactivates voting rights)
    public fun graduate_student(voter_nft: &mut StudentVoterNFT) {
        voter_nft.is_graduated = true;
        voter_nft.voting_power = 0;

        // Update NFT to indicate graduation
        voter_nft.name = b"Graduated";
        voter_nft.description = b"You are no longer eligible to vote.";
        voter_nft.image_url = b"https://example.com/voter-nft-graduated.png";

        event::emit(StudentGraduated {
            student_id: voter_nft.student_id,
        });
    }

    // Function to register a candidate
    public fun register_candidate(voter_nft: &StudentVoterNFT, name: vector<u8>, campaign_promises: vector<u8>, ctx: &mut TxContext): Candidate {
        assert!(voter_nft.voting_power >= 3, 1); // Only Juniors and Seniors can run (3+ votes)

        let candidate = Candidate {
            id: object::new(ctx),
            student_id: voter_nft.student_id,
            name,
            campaign_promises,
            vote_count: 0,
        };

        event::emit(CandidateRegistered {
            student_id: voter_nft.student_id,
            name,
        });

        candidate
    }

    // Function to cast a vote
    public fun cast_vote(voter_nft: &StudentVoterNFT, candidate: &mut Candidate, ctx: &mut TxContext): Vote {
        assert!(!voter_nft.is_graduated, 2); // Ensure voter is active

        let vote = Vote {
            id: object::new(ctx),
            voter_id: voter_nft.student_id,
            candidate_id: candidate.student_id,
        };

        // Apply vote weight based on voting power
        candidate.vote_count = candidate.vote_count + voter_nft.voting_power;

        event::emit(VoteCast {
            voter_id: voter_nft.student_id,
            candidate_id: candidate.student_id,
        });

        vote
    }

    // Function to tally votes and declare results
    public fun tally_votes(
        votes: vector<Vote>,
        candidates: vector<Candidate>,
        ctx: &mut TxContext
    ): (vector<ElectionResult>, vector<Vote>, vector<Candidate>) {
        let mut results: vector<ElectionResult> = vector::empty();
        let mut i = 0;
        while (i < vector::length(&candidates)) {
            let candidate = vector::borrow(&candidates, i);
            let total_votes = candidate.vote_count;

            vector::push_back(&mut results, ElectionResult {
                id: object::new(ctx),
                candidate_id: candidate.student_id,
                total_votes,
            });

            // Emit event for each candidate's result
            event::emit(ElectionResultsTallied {
                candidate_id: candidate.student_id,
                total_votes,
            });

            i = i + 1;
        };
        (results, votes, candidates)
    }
}