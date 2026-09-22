#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum CellState {
    Zero,
    One,
    None,
}

#[derive(Clone)]
struct Board {
    cells: Vec<Vec<CellState>>,
    width: usize,
    height: usize,
    row_offset: usize,
}

impl Board {
    fn new(width: usize, height: usize) -> Self {
        let mut cells = vec![vec![CellState::None; width]; height];

        // Initialize first row: all zeros except the rightmost cell.
        for col in 0..width {
            if col == width - 1 {
                cells[0][col] = CellState::One;
            } else {
                cells[0][col] = CellState::Zero;
            }
        }

        Board {
            cells,
            width,
            height,
            row_offset: 0,
        }
    }

    fn shift_up(&mut self, rows: usize) {
        let shift_amount = rows.min(self.height);

        for i in 0..shift_amount {
            let physical_row = (self.row_offset + i) % self.height;

            for cell in 0..self.width {
                self.cells[physical_row][cell] = CellState::None;
            }
        }

        self.row_offset = (self.row_offset + shift_amount) % self.height;
    }

    #[inline]
    fn physical_row(&self, logical_row: usize) -> usize {
        (self.row_offset + logical_row) % self.height
    }
}

fn update_cell(board: &mut Board, step: usize, cell: usize) -> bool {
    let current_physical = board.physical_row(step);

    if step == 0 || board.cells[current_physical][cell] != CellState::None {
        return false;
    }

    let last_physical = board.physical_row(step - 1);
    let last_row = &board.cells[last_physical];

    let left_neighbor = if cell > 0 {
        last_row[cell - 1]
    } else {
        last_row[board.width - 1]
    };

    let right_neighbor = if cell + 1 < board.width {
        last_row[cell + 1]
    } else {
        last_row[0]
    };

    let old_state = last_row[cell];

    if left_neighbor == CellState::None || right_neighbor == CellState::None {
        return false;
    }

    let new_state =
        if old_state == CellState::One
            && left_neighbor == CellState::One
            && right_neighbor == CellState::One
        {
            CellState::Zero
        } else if old_state == CellState::Zero
            && right_neighbor == CellState::One
        {
            CellState::One
        } else {
            old_state
        };

    board.cells[current_physical][cell] = new_state;
    true
}