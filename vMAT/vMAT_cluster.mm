//
//  vMAT_cluster.mm
//  vMAT
//
//  Created by Kaelin Colclasure on 4/7/13.
//  Copyright (c) 2013 Kaelin Colclasure. All rights reserved.
//

#import "vMAT_Private.h"

#import <iostream>
#import <vector>

#import <Eigen/Dense>


namespace {
    
    using namespace Eigen;
    using namespace std;
    using namespace vMAT;
    
    typedef Mat<double, 3, Dynamic> MatZ; // Input is a 3xN hierarchical cluster tree
    typedef Mat<double, 4, Dynamic> MatY; // Result is a 4x(N+1) inconsistancy matrix
    typedef Mat<double, Dynamic, Dynamic> MatA; // Result is Mx(N+1) assignment matrix
    
    struct Options {
        BOOL useCutoff;
        BOOL useInconsistent;
        int depth;
        vector<double> cutoff;
        vector<int> maxclust;
    };
    
    Options
    clusterOptions(NSArray * options)
    {
        Options opts = { YES, YES, 2, { 0.5, 0.75 }, { } };
        return opts;
    }
    
}

vMAT_Array *
vMAT_cluster(vMAT_Array * matZ,
             NSArray * options)
{
    Options opts = clusterOptions(options);
    
    MatZ Z = vMAT_double(matZ);
    int n = Z.size(1) + 1;
    if (opts.useCutoff) {
        int m = static_cast<int>(opts.cutoff.size());
        VectorXd crit(n - 1);
        MatA A = vMAT_zeros(vMAT_MakeSize(m, n), nil);
        if (opts.useInconsistent) {
            MatY Y = vMAT_inconsistent(Z, opts.depth);
            crit = Y.row(3);
        }
        else {
            crit = Z.row(2);
        }
        cerr << "crit =" << endl << crit << endl;
    }
    return nil;
}
