module suichan::suichan{
    use sui::event;
    use sui::transfer;
    use std::vector;
    use sui::object::{Self, ID, UID};
    use std::string::{Self, String};
    use sui::tx_context::{Self, TxContext};

    const DefaultMaxThreads: u64 = 100;
    const DefaultMaxThreadPosts: u64 = 300;
    const EThreadMaxxed: u64 = 1;

    // A capability representing ownership over a Board.
    struct BoardOwnerCapability has key {
        id: UID,
    }

    // A board, containing threads, which contain posts (strings).
    struct Board has key, store {
        id: UID,
        name: String,
        maxThreads: u64,
        maxThreadPosts: u64,
        threads: vector<vector<String>>,
    }

    struct PostEvent has copy, drop { id: ID }

    fun init(ctx: &mut TxContext) {
        transfer::transfer(
            BoardOwnerCapability {
                id: object::new(ctx),
            }, 
            tx_context::sender(ctx));

        let board = Board {
            id: object::new(ctx),
            name: string::utf8(vector::empty<u8>()),
            maxThreads: DefaultMaxThreads,
            maxThreadPosts: DefaultMaxThreadPosts,
            threads: vector::empty<vector<String>>(),
        };
        transfer::share_object(board);
    }

    // Set the name of the board
    public entry fun rename_board(_:&BoardOwnerCapability, board: &mut Board, name: String) {
        board.name = name;
    }

    // Set the max threads on the board.
    public entry fun set_max_threads(_:&BoardOwnerCapability, board: &mut Board, max_threads: u64) {
        board.maxThreads = max_threads;
    }

    // Set the max replies for a thread on the board.
    public entry fun set_max_thread_posts(_:&BoardOwnerCapability, board: &mut Board, max_thread_posts: u64) {
        board.maxThreadPosts = max_thread_posts;
    }

    // Post a new thread to the board.
    public entry fun post(board: &mut Board, post: String) {
        let thread_count = vector::length<vector<String>>(&board.threads);
        // Drop the last thread if we're at the thread limit
        if (thread_count >= board.maxThreads) {
            // We're at the limit. Pop the last thread.
            let last_thread = vector::pop_back<vector<String>>(&mut board.threads);
            // Delete every post in the thread.
            while (!vector::is_empty<String>(&last_thread)) {
                vector::pop_back<String>(&mut last_thread);
            };
            vector::destroy_empty<String>(last_thread);
        };
        // Add the thread to the board at the top.
        vector::insert<vector<String>>(&mut board.threads, vector::singleton<String>(post), 0);
    }

    // Reply to an existing thread.
    public entry fun reply(board: &mut Board, thread_idx: u64, post: String) {
        let thread = vector::borrow_mut<vector<String>>(&mut board.threads, thread_idx);
        assert!(vector::length<String>(thread) < board.maxThreadPosts, EThreadMaxxed);
        vector::push_back<String>(thread, post);
        event::emit(PostEvent { id: object::id(board) });
    }

    // Test basic operations
    #[test]
    public fun test_board_create() {
        use sui::tx_context;
        let ctx = tx_context::dummy();
        let board = Board {
            id: object::new(&mut ctx),
            name: string::utf8(b"suichan"),
            maxThreads: 1,
            maxThreadPosts: 2,
            threads: vector::empty<vector<String>>(),
        };
        // Add a thread.
        post(&mut board, string::utf8(b"Hello, world!"));
        // Reply to the thread.
        reply(&mut board, 0, string::utf8(b"Hello, yourself!"));
        // Check the contents.
        assert!(vector::length(&board.threads) == 1, 1);
        assert!(vector::length(
            vector::borrow(&board.threads, 0)) == 2, 1);
        // Post again to the board, replacing the original thread.
        post(&mut board, string::utf8(b"Goodbye, world!"));
        // Check the contents.
        assert!(
            *vector::borrow(vector::borrow(&board.threads, 0), 0) == string::utf8(b"Goodbye, world!"), 1);
        // Clean up board.
        transfer::transfer(board, @0xCAFE);
    }
}
