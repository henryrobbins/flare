# Problem Description

A packing facility has an unlimited supply of identical bins, each with a fixed integer capacity W (equivalently, identical stock rolls of width W in a one-dimensional cutting-stock setting). The facility receives a list of items to be packed, where every item has a known positive integer size that does not exceed the bin capacity. Items of the same size may appear multiple times, and the input data specifies the bin capacity, the number of distinct item sizes, the size of each item type, and the number of copies (the demand) required for each item type.

Each item must be assigned to exactly one bin, and within any single bin the total size of the items packed into it cannot exceed the bin capacity W. Every demanded item must be packed (the full demand for each size must be satisfied). The number of bins available is effectively unlimited, but each bin that contains at least one item counts as "used".

The goal is to assign all the demanded items to bins so that the total number of bins used is as small as possible.
