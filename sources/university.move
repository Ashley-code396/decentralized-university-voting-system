/*
/// Module: university
module university::university;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions
#[allow(duplicate_alias)]
module university::elections {
    // Import the event module
    use sui::event;
    use sui::object::{Self, UID, ID};
    use sui::tx_context::{Self, TxContext};
    use sui::transfer;
    use std::vector;

    // Public event structs
    public struct ElectionCreated has copy, drop {
        election_id: ID,
        name: vector<u8>,
        candidates: vector<vector<u8>>,
    }

    public struct VoteCast has copy, drop {
        election_id: ID,
        candidate_index: u64,
    }

    public struct ElectionClosed has copy, drop {
        election_id: ID,
    }

    public struct Election has key, store {
        id: UID, 
        name: vector<u8>, 
        candidates: vector<vector<u8>>, 
        votes: vector<u64>, 
        is_active: bool
    }

    // Create a new election
    public entry fun create_election(
        name: vector<u8>, 
        candidates: vector<vector<u8>>, 
        ctx: &mut TxContext
    ) {
        assert!(vector::length(&candidates) > 1, 100); // Ensure at least two candidates

        let uid = object::new(ctx); // Create a new UID
        let mut votes = vector::empty<u64>();//mut means the value of i can be changed later
        let length = vector::length(&candidates);//let initialize the variable at the time of declaration
        let mut i = 0;
// Gets the total number of candidates (length).
// Loops through each candidate and adds a 0 to the votes vector.
// The votes vector stores vote counts in the same order as candidates.
        while (i < length) {
            vector::push_back(&mut votes, 0); // Initialize votes for each candidate
            i = i + 1;
        };
        
        // Get the election ID for the event before creating the Election object
        let id_copy = object::uid_to_inner(&uid);
        
        // Create the Election object
        let election = Election { 
            id: uid, 
            name: copy name, // copied from the function parameter.
            candidates: copy candidates, // copied from the function parameter.
            votes, // initialized so each candidate starts with zero votes.
            is_active: true 
        };

        // Transfer the Election object to the sender
        transfer::transfer(election, tx_context::sender(ctx));// Moves ownership of the election to the creator.
                                              // Prevents loss of the election object.
                                             // Ensures security—only the owner can manage the election later.

        // Emit an event
        event::emit(ElectionCreated {
            election_id: id_copy,
            name,
            candidates,
        });
    }

    // Vote for a candidate in an election
    public entry fun vote(
        election: &mut Election,
        candidate_index: u64,
        _ctx: &TxContext
    ) {
        assert!(election.is_active, 101); // Ensure the election is active
        assert!(candidate_index < vector::length(&election.candidates), 102); //  Ensures the voter is selecting a valid candidate.

        // Increment the vote count for the selected candidate
        let mut vote_count = vector::borrow_mut(&mut election.votes, candidate_index);
        *vote_count = *vote_count + 1;

        // Emit an event
        event::emit(VoteCast {
            election_id: object::uid_to_inner(&election.id),
            candidate_index,
        });
    }

    // Close an election (only the owner can close it)
    public entry fun close_election(
        election: &mut Election,
        ctx: &TxContext
    ) {
        assert!(election.is_active, 103); //Ensures that the election is still open before closing it
        assert!(tx_context::sender(ctx) == object::uid_to_address(&election.id), 104); // Ensure the caller is the owner

        // Mark the election as closed
        election.is_active = false;

        // Emit an event
        event::emit(ElectionClosed {
            election_id: object::uid_to_inner(&election.id),
        });
    }

    // View election results
    public fun view_results(election: &Election): vector<u64> {
        assert!(!election.is_active, 105); // Ensures that results can only be viewed after the election is closed
        *&election.votes  //Retrieves the vector of votes, where each index corresponds to a candidate
    }
}