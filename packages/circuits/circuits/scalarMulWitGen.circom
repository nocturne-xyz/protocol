// constant-time witness-generation-only scalar mul

pragma circom 2.1.0;

// double-always-add method
function scalarMul(px, py, n, scalar) {
    var res[2];
    res[0] = 0;
    res[1] = 1;

    for (var i = 0; i < n; i++) {
        var r1[2];
        var r2[2];

        r1 = pointDouble(res[0], res[1]);
        r2 = pointAdd(r1[0], r1[1], px, py);

        // select
        res[0] = scalar[n - i - 1] * r2[0] + (1 - scalar[n - i - 1]) * r1[0];
        res[1] = scalar[n - i - 1] * r2[1] + (1 - scalar[n - i - 1]) * r1[1];
    }

    return res;
}

function pointAdd(x1,y1,x2,y2) {
    var a = 168700;
    var d = 168696;

    var res[2];
    res[0] = (x1*y2 + y1*x2) / (1 + d*x1*x2*y1*y2);
    res[1] = (y1*y2 - a*x1*x2) / (1 - d*x1*x2*y1*y2);
    return res;
}

function pointDouble(x,y) {
    var a = 168700;
    var d = 168696;

    var res[2];
    res[0] = (2*x*y) / (a*x*x + y*y);
    res[1] = (y*y - a*x*x) / (2 - a*x*x - y*y);
    return res;
}