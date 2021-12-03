# -*- coding: utf-8 -*-
#
# Copyright (c) 2021, SkyFoundry LLC
# Licensed under the Academic Free License version 3.0
#
# History:
#   02 Nov 2021  Matthew Giannini  Creation
#

class Grid:

    @staticmethod
    def empty_grid():
        return Grid()

    @staticmethod
    def from_dataframe(frame):
        cols = frame.columns
        gb = GridBuilder()
        gb.add_col_names(cols.tolist())
        for idx, row in frame.iterrows():
            gb.add_row(row.tolist())
        return gb.to_grid()

    def __init__(self, meta=None, cols=None, cols_by_name=None, rows=None):
        if meta is None:
            meta = {}
        if cols is None:
            cols = []
        if cols_by_name is None:
            cols_by_name = {}
        if rows is None:
            rows = []

        self._meta = meta
        self._cols = cols
        self._cols_by_name = cols_by_name
        self._rows = rows

    def meta(self):
        return self._meta

    def cols(self):
        return self._cols

    def col_names(self):
        return list(map(lambda col: col.name(), self.cols()))

    def col(self, name, checked=True):
        c = self._cols_by_name.get(name)
        if c:
            return c
        if checked:
            raise NameError(f'Column not found: {name}')
        return None

    def has(self, name):
        return self.col(name, False) is not None

    def is_empty(self):
        return self.size() == 0

    def size(self):
        return len(self._rows)

    def rows(self):
        return self._rows

    def first(self):
        return self.get(0)

    def get(self, index):
        return self._rows[index]

    def val(self, row, col):
        return self.get(row).val(self._cols[col])

    def to_dataframe(self):
        import pandas
        rows = list(map(lambda row: row.cells(), self._rows))
        return pandas.DataFrame(data=rows, columns=self.col_names())

# Grid


class GridBuilder:
    def __init__(self):
        self._grid = Grid()
        self._cols_by_name = None
        self._cols = []
        self._rows = []

    def set_meta(self, meta):
        self._grid._meta = meta
        return self

    def add_col(self, name, meta=None):
        if meta is None:
            meta = {}
        if self._cols_by_name:
            raise Exception("Cannot add columns after adding rows")
        if not GridBuilder.is_tagname(name):
            raise Exception(f'Invalid column name: {name}')
        self._cols.append(GridCol(len(self._cols), name, meta))
        return self

    def add_col_names(self, names):
        for name in names:
            self.add_col(name)
        return self

    def add_row(self, cells):
        if not self._cols_by_name:
            self._finish_cols()
        if len(cells) != len(self._cols):
            raise Exception(f'Num cells {len(cells)} != Num cols {len(self._cols)}')
        self._rows.append(GridRow(self._grid, cells))
        return self

    def to_grid(self):
        if not self._cols_by_name:
            self._finish_cols()
        self._grid._cols = self._cols
        self._grid._cols_by_name = self._cols_by_name
        self._grid._rows = self._rows
        return self._grid

    def _finish_cols(self):
        acc = {}
        for col in self._cols:
            if col.name() in acc:
                raise Exception(f'Duplicate column name: {col.name()}')
            acc[col.name()] = col
        self._cols_by_name = acc

    @staticmethod
    def is_tagname(n):
        if len(n) == 0 or n[0].isupper():
            return False
        for c in n:
            if not c.isalnum() and c != "_":
                return False
        return True

# Grid Builder


class GridCol:
    def __init__(self, i, n, m):
        self.__index = i
        self.__name = n
        self.__meta = m

    def index(self):
        return self.__index

    def name(self):
        return self.__name

    def meta(self):
        return self.__meta

# GridCol


class GridRow:
    def __init__(self, grid, cells):
        self.__grid = grid
        self.__cells = cells

    def cells(self):
        return self.__cells

    def grid(self):
        return self.__grid

    def val(self, col):
        return self.__cells[col.index()]

# GridRow
