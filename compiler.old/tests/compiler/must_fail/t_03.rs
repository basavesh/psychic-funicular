fn test() {
    var! {
        x : stack! (b64);
    }
    code! {
        x = b64!(0);
    }
    var! {
        _y : stack! (b64);
    }
}

/*
START:CMD
ARG="print[input]"
END:CMD
*/