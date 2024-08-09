const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;

const expect = std.testing.expect;
const expectError = std.testing.expectError;

const Evaluation = packed struct {
    black_score : u32,
    white_score : u32,
};

const ColoursSeen = packed struct {
    black : bool,
    white : bool,
};

const Colour = enum {
    black,  
    white, 
    empty, 
};

// The gamestate
// each board element is represented by a u2.
// 0 represents empty; 1 = black; 2 = white
//
// length defines both the length and width of the square board.
pub fn GameState(comptime length: u8) type {
    return struct {
        const Self = @This();
        pub const vertices : u16 = @as(u16, length) * @as(u16, length);
        const Board  = [length][length]u2;
        const Island = [length][length]u1;
        const directions = [4][2]i8{
            .{-1, 0},   // above
            .{1, 0},    // below
            .{0, -1},   // left
            .{0, 1},    // right
        };

        last_move_was_pass : bool,
        blacks_move : bool, // black starts in Go.

        board : Board,
        _current_island : Island, // The current island we are checking for liberties.

        // NOTE could these sizes be reduced?
        // There must be a theoretical limit on the number of possible captures in a game of Go;
        // contingent on the super-ko rules being used (i.e. forbidding infinite loops).
        black_captures : u32,
        white_captures : u32,

        // the i, j co-ordinates of a move which captured a single-stone
        // (relevant for the kō rule). Negative values are if the last move
        // did not involve a single-stone being captured.
        single_capture : [2]i8,

        _colours_seen_adjacent_to_island : ColoursSeen,

        /// Initialize a new gamestate.
        pub fn init() Self {
            return Self{
                .last_move_was_pass = false,
                .blacks_move = true,
                .board = .{.{0} ** length} ** length,
                ._current_island = undefined,
                .black_captures = 0,
                .white_captures = 0,
                .single_capture = .{-1, -1},
                ._colours_seen_adjacent_to_island = ColoursSeen{ .black = false, .white = false},
            };
        }

        /// check if a vertex has liberties; if not, return the number of stones captured.
        fn checkVertex(self : *Self, i : u8, j : u8, inactive : u2) u16 {
            var captured_stones : u16 = 0;
            self._current_island = .{.{0} ** length} ** length;
            if (self.board[i][j] == inactive) {
                if (self.hasLiberties(i, j) == false) {
                    captured_stones += self.clearCapturedStones();
                }
            }
            return captured_stones;
        }

        fn clearCapturedStones(self : *Self) u16 {
            var captured_stones : u16 = 0;
            for (0..length) |i| {
                for (0..length) |j| {
                    if (self._current_island[i][j] == 1) {
                        self.board[i][j] = 0;
                        captured_stones += 1;
                    }
                }
            }
            return captured_stones;
        }

        /// Returns false if the move was not allowed i.e. self-capture or vertex already taken
        pub fn playStone(self : *Self, i : u8, j : u8) bool {
            // Check if the vertex is already taken!
            if (self.board[i][j] != 0) return false;

            const active   : u2 = if (self.blacks_move) 1 else 2;
            const inactive : u2 = if (self.blacks_move) 2 else 1;

            // places the stone -- can be unwound later in this method if the play is illegal.
            self.board[i][j] = active;

            var captured_stones : u16 = 0;

            // Check adjacent stones for captures
            for (directions) |direction| {
                const ni = @as(i16, i) + direction[0];
                const nj = @as(i16, j) + direction[1];

                if (ni >= 0 and ni < length and nj >= 0 and nj < length) {
                    captured_stones += self.checkVertex(@intCast(ni), @intCast(nj), inactive);
                }
            }

            // check:
            //  that no self-capture occurs if this play is finalized.
            //  self-capture occurs iff no adjacent island is captured.
            if (captured_stones == 0) {
                // This check will, funnily enough, actually *capture* the placed stone
                // which leaves the board as it was before the illegal move.
                if (self.checkVertex(i, j, active) > 0) {
                    // self-capture isn't allowed
                    return false;
                }
            }

            // check the kō rule:
            //      'One may not capture just one stone if that stone was played on the previous move and
            //      that move also captured just one stone.'

            if (captured_stones == 1) {
                const last_move_was_single_capture = self.single_capture[0] > 0 and self.single_capture[1] > 0;
                if (last_move_was_single_capture) {
                    const i_last : u8  = @intCast(self.single_capture[0]);
                    const j_last : u8  = @intCast(self.single_capture[1]);
                    
                    const last_stone_was_captured = (self.board[i_last][j_last] == 0);
                    if (last_stone_was_captured) {
                        // rollback the illegal move:
                        // place the opponent's stone back where it was illegally taken
                        // and remove the offending player's stone.
                        self.board[i_last][j_last] = inactive;
                        self.board[i][j] = 0;
                        return false;
                    }
                }
            }

            // update the score
            if (self.blacks_move)   { self.black_captures += captured_stones; }
            else                    { self.white_captures += captured_stones; }

            if (captured_stones == 1) {
                // These are for checking if the kō rule is violated next turn.
                // Only set these if exactly one stone was captured legally.
                self.single_capture[0] = @intCast(i);
                self.single_capture[1] = @intCast(j);
            } else {
                self.single_capture[0] = -1;
                self.single_capture[1] = -1;
            }
            // toggle active player
            self.last_move_was_pass = false;
            self.nextPlayer();
            return true;
        }

        fn nextPlayer(self : *Self) void {
            self.blacks_move = !self.blacks_move;
        }

        /// Pass the turn.
        /// Returns true if the game has ended (two successive passes).
        pub fn passTurn(self : *Self) bool {
            if (self.last_move_was_pass == true) {
                return true;
            }
            self.nextPlayer();
            self.last_move_was_pass = true;
            return false;
        }

        /// Return whether or not a co-ordinate has liberties,
        /// including any contiguous stones.
        fn hasLiberties(self : *Self, i : u8, j : u8) bool {
            // should be 1 or 2 -- not 0!!!
            // NOTE could this be 0 if we're searching for controlled territories?
            const colour : u2 = self.board[i][j];

            // this is a bitmask where 1's form the current island,
            // where an 'island' is a contiguous block of adjacent (non-diagonally)
            // stones.
            self._current_island[i][j] = 1;

            // recursively search for liberties.
            // return `true` if a single liberty is found -- one is sufficient.
            // return `false` if the island has no liberties
            for (directions) |direction| {
                const ni = @as(i16, i) + direction[0];
                const nj = @as(i16, j) + direction[1];

                if (ni >= 0 and ni < length and nj >= 0 and nj < length) {
                    const new_i : u8 = @intCast(ni);
                    const new_j : u8 = @intCast(nj);

                    if (self.board[new_i][new_j] == 0) return true;
                    if (self.board[new_i][new_j] == colour and self._current_island[new_i][new_j] == 0) {
                        // recursively search for liberties for this island!
                        if (self.hasLiberties(new_i, new_j)) return true;
                    }
                }
            }
            return false;
        }

        /// Who owns the island containing i, j?
        fn computeTerritoryOwner(self : *Self, i : u8, j : u8) void {
            // this is a bitmask where 1's form the current island,
            // where an 'island' is a contiguous block of adjacent (non-diagonally)
            // **empty vertices**.
            self._current_island[i][j] = 1;
            // print("\t\t{any}, {any}\n", .{i, j});

            // recursively search for adjacent stones of white and black
            // also constructs the *full* island (important)
            for (directions) |direction| {
                const ni = @as(i16, i) + direction[0];
                const nj = @as(i16, j) + direction[1];

                if (ni >= 0 and ni < length and nj >= 0 and nj < length) {
                    const new_i : u8 = @intCast(ni);
                    const new_j : u8 = @intCast(nj);
                    
                    // already visited
                    if (self._current_island[new_i][new_j] == 1) {
                        continue;
                    }

                    switch (self.board[new_i][new_j]) {
                        1 => self._colours_seen_adjacent_to_island.black = true,
                        2 => self._colours_seen_adjacent_to_island.white = true,
                        // Recursively expand the territory island
                        0 => self.computeTerritoryOwner(new_i, new_j),
                        3 => break, // should be impossible! 
                    }
                }
            }
            return;
        }

        /// Return the captures + territories for black and white, respectively.
        pub fn computeScores(self : *Self) Evaluation {
            // loop through each island and check if all of it's liberties are a single colour
            // if so, increment the territory score for that colour.

            var black_territory : u16 = 0;
            var white_territory : u16 = 0;

            self._current_island = .{.{0} ** length} ** length;

            // _ = self.renderBoard();
            for (self.board, 0..) |row, i| {
                for (row, 0..) |vertex, j| {
                    if (vertex != 0) {
                        // Skip occupied vertices.
                        continue;
                    }

                    self.computeTerritoryOwner(@intCast(i), @intCast(j));
                    if (self._colours_seen_adjacent_to_island.black and self._colours_seen_adjacent_to_island.white) {
                        continue;
                    }
                    if (!self._colours_seen_adjacent_to_island.black and !self._colours_seen_adjacent_to_island.white) {
                        continue;
                    }

                    if (self._colours_seen_adjacent_to_island.black) {
                        print("BLACK TERRITORY FOUND AT ISLAND : {any}, {any}\n", .{i, j});
                        black_territory += self.clearCapturedStones();
                    } 
                    if (self._colours_seen_adjacent_to_island.white) {
                        print("WHITE TERRITORY FOUND AT ISLAND : {any}, {any}\n", .{i, j});
                        white_territory += self.clearCapturedStones();
                    }

                    // clear the tracked territory
                    self._current_island = .{.{0} ** length} ** length;
                    
                    self._colours_seen_adjacent_to_island.black = false;
                    self._colours_seen_adjacent_to_island.white = false;
                }
            }
            print("WHITE CAPTURES : {any}\n", .{self.white_captures});
            print("WHITE TERRITORY: {any}\n", .{white_territory});
            
            return Evaluation{
                .black_score=self.black_captures + black_territory,
                .white_score=self.white_captures + white_territory,
            };
        }

        // TODO use the returned string instead of printing ad-hoc
        pub fn renderBoard(self : *Self) []u8 {
            // loop through each of the board's rows
            // loop through each of the rows' elements
            // self._render

            var string : [vertices + length]u8 = undefined;
            for (self.board, 0..) |row, i| {
                print("\n", .{});
                for (row, 0..) |vertex, j| {
                    print("{any}", .{vertex});
                    string[(length * i) + j] = vertex;
                }
            }
            print("\n\n", .{});
            return &string;
        }
    };
}

// test "test create board type" {
//     const state : type = GameState(2);
//     try expect(state.vertices == 4);
// }

// test "board is all zeros" {
//     const state = GameState(2).init();

//     for (state.board, 0..) |row, row_index| {
//         for (row, 0..) |cell, column_index| {
//             if (row_index == column_index) {
//                 try expect(cell == 0);
//             }
//         }
//     }
// }

// test "play stone" {
//     var state = GameState(2).init();
//     _ = state.playStone(0, 0);
//     try expect(state.board[0][0] == 1);
//     try expect(state.blacks_move == false);
// }

// test "play multiple stones" {
//     var state = GameState(2).init();
//     _ = state.playStone(0, 0);
//     _ = state.playStone(1, 1);

//     try expect(state.board[0][0] == 1);
//     try expect(state.board[1][1] == 2);
//     try expect(state.blacks_move == true);
// }

// test "pass turn" {
//     var state = GameState(2).init();
//     try expect(state.blacks_move == true);

//     _ = state.passTurn();
//     try expect(state.blacks_move == false);
// }

// test "game ends after two successive passes" {
//     var state = GameState(2).init();
//     try expect(state.passTurn() == false);
//     try expect(state.passTurn() == true);
// }

// test "capture a stone" {
//     var state = GameState(2).init();
//     _ = state.playStone(0, 0);
//     _ = state.playStone(1, 0);
//     _ = state.playStone(1, 1); // black captures the white stone in the corner

//     try expect(state.board[1][0] == 0);
//     try expect(state.black_captures == 1);
// }

// test "capture a block of stones" {
//     var state = GameState(2).init();
//     _ = state.playStone(0, 1);
//     _ = state.playStone(1, 1);
//     _ = state.playStone(0, 0);
//     _ = state.playStone(1, 0);
//     try expect(state.black_captures == 0);
//     try expect(state.white_captures == 2);
// }

// test "self-capture fails" {
//     var state = GameState(2).init();
//     _ = state.playStone(0, 0);
//     _ = state.passTurn();
//     _ = state.playStone(1, 1);

//     try expect(state.blacks_move == false);
//     try expect(state.playStone(1, 0) == false);
//     try expect(state.blacks_move == false);
//     try expect(state.board[1][0] == 0);
// }

// test "test the kō rule" {
//     var state = GameState(5).init();
//     _ = state.playStone(2, 0); // black
//     _ = state.playStone(1, 2); // white
//     _ = state.playStone(1, 1); // black
//     _ = state.playStone(3, 2); // white
//     _ = state.playStone(3, 1); // black
//     _ = state.playStone(2, 3); // white
//     _ = state.playStone(2, 2); // black
//     _ = state.playStone(2, 1); // white captures

//     try expect(state.white_captures == 1);
//     try expect(state.playStone(2, 2) == false); // black tries to re-capture -- illegal due to kō rule
//     try expect(state.black_captures == 0);
//     _ = state.playStone(4, 4); // black plays another, unrelated move...
//     _ = state.playStone(4, 3); // so does white now...

//     try expect(state.playStone(2, 2) == true); // black tries to re-capture again -- kō rule does not apply
//     try expect(state.black_captures == 1);
// }

// test "eval starts at 0; 0" {
//     var state = GameState(19).init();
//     const evaluation = state.computeScores();
//     try expect(evaluation.black_score == 0);
//     try expect(evaluation.white_score == 0);
// }

// test "evaluating score with capture" {
//     var state = GameState(2).init();
//     _ = state.playStone(1, 0);
//     _ = state.playStone(0, 0);
//     _ = state.playStone(0, 1); // black captures
//     // _ = state.renderBoard();

//     const evaluation = state.computeScores();
//     print("BLACK SCORE {any}", .{evaluation.black_score});
//     // One capture, two territories (0, 0), (1, 1)
//     try expect(evaluation.black_score == 3);
//     try expect(evaluation.white_score == 0);
// }

test "capture two territories" {
    var state = GameState(2).init();
    _ = state.playStone(0, 0);
    _ = state.playStone(1, 0);

    _ = state.playStone(0, 1);
    _ = state.playStone(1, 1); // white captures both of black's stones

    const evaluation = state.computeScores();
    // One capture, two territories (0, 0), (1, 1)
    try expect(evaluation.black_score == 0);
    try expect(evaluation.white_score == 4);
}
