//
//  vMAT.m
//  vMAT
//
//  Created by Kaelin Colclasure on 3/24/13.
//  Copyright (c) 2013 Kaelin Colclasure. All rights reserved.
//

#import "vMAT.h"

#import <BlocksKit/BlocksKit.h>


void
vMAT_eye(vDSP_Length rows,
         vDSP_Length cols,
         void (^outputBlock)(float output[],
                             vDSP_Length outputLength,
                             bool * keepOutput))
{
    long lenE = rows * cols;
    float * E = calloc(lenE, sizeof(*E));
    long diag = fminf(rows, cols);
    for (int row = 0;
         row < diag;
         row++) {
        E[row * cols + row] = 1.f;
    }
    bool keepOutput = false;
    outputBlock(E, lenE, &keepOutput);
    if (!keepOutput) {
        free(E);
    }
}

void
vMAT_linkage(const float pdistv[],
             vDSP_Length pdistvLength,
             void (^outputBlock)(float output[],
                                 vDSP_Length outputLength,
                                 bool * keepOutput))
{
    long n = ceil(sqrt(pdistvLength));
    long idx;
    // First we need to reduce distanceMatrix to a vector (Y).
    // (The order is the same as Matlab's pdist results.)
    long lenY = n * (n - 1) / 2;
    float * Y = calloc(lenY, sizeof(*Y));
    // We also need a vector of indexes for keeping track of the cluster assignments (R).
    long * R = calloc(n, sizeof(*R));
    idx = 0;
    for (long row = 0;
         row < n;
         row++) {
        for (long col = row + 1;
             col < n;
             col++) {
            Y[idx] = pdistv[row * n + col];
            ++idx;
        }
        R[row] = row;
    }
    // Now build the cluster tree in an (n-1)x3 matrix (Z).
    long lenZ = 3 * (n - 1);
    float * Z = calloc(lenZ, sizeof(*Z));
    @autoreleasepool {
        NSMutableIndexSet * I1 = [NSMutableIndexSet indexSet];
        NSMutableIndexSet * I2 = [NSMutableIndexSet indexSet];
        NSMutableIndexSet * I3 = [NSMutableIndexSet indexSet];
        NSMutableIndexSet * U = [NSMutableIndexSet indexSet];
        NSMutableIndexSet * I = [NSMutableIndexSet indexSet];
        NSMutableIndexSet * J = [NSMutableIndexSet indexSet];
        long m = n;
        float fm = m;
        for (idx = 0;  // row of Z we are updating
             idx < (n - 1);
             idx++) {
            float minDist = NAN;
            vDSP_Length minIdx = -1;
            vDSP_minvi(Y, 1, &minDist, &minIdx, lenY);
            // Calculate indexes of clusters to merge into a new cluster (i and j).
            float fk = minIdx + 1;
            float fi = floor(fm + 1 / 2.f - sqrtf(powf(fm, 2.f) - fm + 1 / 4.f - 2.f * (fk - 1)));
            long i = lrintf(fi) - 1;
            float fj = fk - (fi - 1) * (fm - fi / 2.f) + fi;
            long j = lrintf(fj) - 1;
            // Update the row of Z with the cluster numbers and the distance between them.
            Z[idx * 3 + 0] = fminf(R[i], R[j]); Z[idx * 3 + 1] = fmaxf(R[i], R[j]); Z[idx * 3 + 2] = minDist;
            // Update Y.
            [I1 removeAllIndexes]; [I2 removeAllIndexes]; [I3 removeAllIndexes];
            [U removeAllIndexes];
            [I removeAllIndexes]; [J removeAllIndexes];
            if (i > 0) [I1 addIndexesInRange:NSMakeRange(0, i)];
            [I2 addIndexesInRange:NSMakeRange(i + 1, j - i - 1)];
            [I3 addIndexesInRange:NSMakeRange(j + 1, m - j - 1)];
            [U addIndexes:I1]; [U addIndexes:I2]; [U addIndexes:I3];
            [I addIndexes:[I1 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (findex * (fm - (findex + 1) / 2.f) - fm + fi) - 1;
            }]];
            [I addIndexes:[I2 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (fi * (fm - (fi + 1) / 2.f) - fm + findex) - 1;
            }]];
            [I addIndexes:[I3 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (fi * (fm - (fi + 1) / 2.f) - fm + findex) - 1;
            }]];
            [J addIndexes:[I1 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (findex * (fm - (findex + 1) / 2.f) - fm + fj) - 1;
            }]];
            [J addIndexes:[I2 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (findex * (fm - (findex + 1) / 2.f) - fm + fj) - 1;
            }]];
            [J addIndexes:[I3 map:^NSUInteger(NSUInteger index) {
                const float findex = index + 1;
                return (fj * (fm - (fj + 1) / 2.f) - fm + findex) - 1;
            }]];
            __block NSUInteger idxJ = [J firstIndex];
            [I enumerateIndexesUsingBlock:^(NSUInteger idxI,
                                            BOOL * stop) {
                Y[idxI] = fminf(Y[idxI], Y[idxJ]);
                idxJ = [J indexGreaterThanIndex:idxJ];
            }];
            [J addIndex:(fi * (m - (fi + 1) / 2) - m + fj) - 1];
            long idx2 = 0;
            for (long col = 0;
                 col < lenY;
                 col++) {
                if ([J containsIndex:col]) continue;
                Y[idx2] = Y[col];
                ++idx2;
            }
            lenY = idx2;
            --m; fm = m;
            R[i] = n + idx;
            for (idx2 = j;
                 idx2 < n - 1;
                 idx2++) {
                R[idx2] = R[idx2 + 1];
            }
        }
    }
    free(Y);
    free(R);
    bool keepOutput = false;
    outputBlock(Z, lenZ, &keepOutput);
    if (!keepOutput) {
        free(Z);
    }
}

void
vMAT_pdist(const float sample[],
           vDSP_Length rows,
           vDSP_Length cols,
           void (^outputBlock)(float output[],
                               vDSP_Length outputLength,
                               bool * keepOutput))
{
    __block float * D = NULL;
    __block long lenD = 0;
    vMAT_pdist2(sample, rows, sample, rows, cols, ^(float * output,
                                                    vDSP_Length outputLength,
                                                    bool * keepOutput) {
        D = output;
        lenD = outputLength;
        *keepOutput = true;
    });
    // Now reduce the full distance matrix to a vector of lengths (Y).
    // (The order is the same as Matlab's pdist results.)
    long n = ceil(sqrt(lenD));
    long lenY = n;
    float * Y = calloc(lenY, sizeof(*Y));
    long idxY = 0;
    for (long row = 0;
         row < n;
         row++) {
        for (long col = row + 1;
             col < n;
             col++) {
            Y[idxY] = D[row * n + col];
            ++idxY;
        }
    }
    free(D);
    bool keepOutput = false;
    outputBlock(Y, lenY, &keepOutput);
    if (!keepOutput) {
        free(Y);
    }
}

void
vMAT_pdist2(const float sampleA[],
            vDSP_Length rowsA,
            const float sampleB[],
            vDSP_Length rowsB,
            vDSP_Length cols,
            void (^outputBlock)(float output[],
                                vDSP_Length outputLength,
                                bool * keepOutput))
{
    // We need space to store a full distance matrix (D).
    long lenD = rowsA * rowsB;
    float * D = calloc(lenD, sizeof(*D));
    long idxD = 0;
    for (long idxA = 0;
         idxA < rowsA;
         idxA++) {
        for (long idxB = 0;
             idxB < rowsB;
             idxB++) {
            vDSP_distancesq(&sampleA[idxA * cols], 1, &sampleB[idxB * cols], 1, &D[idxD], cols);
            D[idxD] = sqrtf(D[idxD]);
            ++idxD;
        }
    }
    bool keepOutput = false;
    outputBlock(D, lenD, &keepOutput);
    if (!keepOutput) {
        free(D);
    }
}
