#![feature(const_fn)]

extern crate extprim;

pub mod var;

use std::collections::HashMap;
use std::cell::RefCell;

// simulate heap in rust for testing
thread_local! {
    pub static MEM_ARRAY: RefCell<HashMap<usize,u64>> = RefCell::new(HashMap::new());
}

#[macro_use]
pub mod jasmin {
    use MEM_ARRAY;
    use std::ops::{Index,IndexMut};

    pub fn addr_to_idx(p: u64,off: usize) -> usize {
        ((p as usize) + off) / 8
    }

    pub fn store_mem(p: u64,off: usize,x: u64) {
        let i = addr_to_idx(p,off);
        MEM_ARRAY.with(|m| {
            m.borrow_mut().insert(i,x);
        });
    }

    pub fn load_mem(p: u64,off: usize) -> u64 {
        let i = addr_to_idx(p,off);
        let mut x = None;
        MEM_ARRAY.with(|m| {
            let m = m.borrow();
            let r = m.get(&i);
            x = Some(*r.unwrap());
        });
        x.unwrap()
    }

    #[derive(Clone,Copy,Debug,PartialEq,Eq)]
    pub struct Jval<T> {
        pub val: T
    }
    
    #[allow(non_camel_case_types)]
    pub type b1 = Jval<bool>;

    #[allow(non_camel_case_types)]
    pub type b8 = Jval<u8>;

    #[allow(non_camel_case_types)]
    pub type b16 = Jval<u16>;

    #[allow(non_camel_case_types)]
    pub type b32 = Jval<u32>;

    #[allow(non_camel_case_types)]
    pub type b64 = Jval<u64>;

    pub trait ToJval<T> {
        fn to_jval(self : Self) -> Jval<T>;
    }

    impl<T> ToJval<T> for Jval<T> {
        fn to_jval(self : Self) -> Jval<T> { self }
    }

    // we define these explicitly, don't want to automatically lift e.g. arrays
    impl ToJval<u64> for u64 {
        fn to_jval(self) -> b64 { Jval { val: self } }
    }
    impl ToJval<u32> for u32 {
        fn to_jval(self) -> b32 { Jval { val: self } }
    }
    impl ToJval<u16> for u16 {
        fn to_jval(self) -> b16 { Jval { val: self } }
    }
    impl ToJval<u8> for u8 {
        fn to_jval(self) -> b8 { Jval { val: self } }
    }
    impl ToJval<bool> for bool {
        fn to_jval(self) -> b1 { Jval { val: self } }
    }

    impl Index<Jval<u64>> for [b64] {
        type Output = b64;

        fn index(&self, i: b64) -> &b64 {
            &self[i.val as usize]
        }
    }

    impl IndexMut<Jval<u64>> for [b64] {

        fn index_mut(&mut self, i: b64) -> &mut b64 {
            &mut self[i.val as usize]
        }
    }


    #[macro_export]
    macro_rules! code {
        ( $($arg:tt)* ) => {
            __j_internal!( $( $arg )* )
        }
    }

    #[macro_export]
    macro_rules! __j_internal {
        () => {
            ()
        };
        
        // * Assignments with destructuring match

        // = assignment with 5-tuple
        ( ($v0: expr, $v1: expr, $v2: expr, $v3: expr, v4: expr) = $e: expr ; $($rest:tt)* ) => {
            let t = $e; $v0 = t.0; $v1 = t.1; $v2 = t.2; $v3 = t.3; $v4 = t.4;
            __j_internal!{ $($rest)* }
        };
        // = assignment with 4-tuple
        ( ($v0: expr, $v1: expr, $v2: expr, $v3: expr) = $e: expr ; $($rest:tt)* ) => {
            let t = $e; $v0 = t.0; $v1 = t.1; $v2 = t.2; $v3 = t.3;
            __j_internal!{ $($rest)* }
        };
        // = assignment with triple
        ( ($v0: expr, $v1: expr, $v2: expr) = $e: expr ; $($rest:tt)* ) => {
            let t = $e; $v0 = t.0; $v1 = t.1; $v2 = t.2;
            __j_internal!{ $($rest)* }
        };        
        // = assignment with pair
        ( ($v0: expr, $v1: expr) = $e: expr ; $($rest:tt)* ) => {
            let t = $e; $v0 = t.0; $v1 = t.1;
            __j_internal!{ $($rest)* }
        };

        // * Memory load and store

        // load to ident
        ( $v0: ident              = MEM [ $vp: ident + $e:expr ] ; $($rest:tt)* ) => {
            $v0 = load_mem($vp.val,$e).to_jval();
            __j_internal!{ $($rest)* }
        };
        // load to array-index
        ( $v0: ident [ $ie: expr ] = MEM [ $vp: ident + $e:expr ] ; $($rest:tt)* ) => {
            $v0[$ie] = load_mem($vp.val,$e).to_jval();
            __j_internal!{ $($rest)* }
        };
        // store
        ( MEM [ $vp: ident + $e:expr ] = $x: expr; $($rest:tt)* ) => {
            store_mem($vp.val,$e,$x.val);
            __j_internal!{ $($rest)* }
        };
     
        // * Assignment

        // array assignment: v = [ a1, .., ak ]
        ( $v0: ident = [ $( $e: expr),+ ] ; $($rest:tt)* ) => {
            $v0 = [ $( $e.to_jval()),+ ];
            __j_internal!{ $($rest)* }
        };
        // array assignment: v = [ v; n ]
        ( $v0: ident = [ $e: expr; $n: expr ] ; $($rest:tt)* ) => {
            $v0 = [ $e.to_jval(); $n ];
            __j_internal!{ $($rest)* }
        };
        // standard assignment: v = ..
        ( $v0: ident = # $v1: expr ; $($rest:tt)* ) => {
            $v0 = $v1.to_jval();
            __j_internal!{ $($rest)* }
        };
        // standard assignment: v = ..
        ( $v0: ident = $e: expr ; $($rest:tt)* ) => {
            $v0 = $e;
            __j_internal!{ $($rest)* }
        };
        // standard assignment: v = ..
        ( $v0: ident [ $e0: expr ] = # $v1: expr ; $($rest:tt)* ) => {
            $v0[$e0] = $v1.to_jval();
            __j_internal!{ $($rest)* }
        };

        // standard assignment: a[..] = ..
        ( $v0: ident [ $e0: expr ] = $v1: expr ; $($rest:tt)* ) => {
            $v0[$e0] = $v1;
            __j_internal!{ $($rest)* }
        };

        // * Conditional move

        // = conditional move negated: ident = ...
        ( when ! $c: ident { $v0: ident = $v1: expr } ; $($rest: tt)* ) => {
            if ! $c.val { $v0 = $v1; }
            __j_internal!{ $($rest)* }
        };
        // = conditional move: ident = ...
        ( when $c : ident { $v0: ident = $v1: expr }; $($rest: tt)* ) => {
            if $c.val { $v0 = $v1; }
            __j_internal!{ $($rest)* }
        };
        // = conditional move negated
        ( when ! $c: ident { $v0: ident [ $idx: expr ] = $v1: expr } ; $($rest: tt)* ) => {
            if ! $c.val { $v0[$idx] = $v1; }
            __j_internal!{ $($rest)* }
        };
        // = conditional move
        ( when $c : ident { $v0: ident [ $idx: expr ] = $v1: expr }; $($rest: tt)* ) => {
            if $c.val { $v0[$idx] = $v1; }
            __j_internal!{ $($rest)* }
        };

        // 
        // * Control flow

        // for i in .. { .. }
        ( for $v0: ident in ( $rng: expr ) { $( $body: tt )* } $($rest:tt)* ) => {
            for $v0 in $rng { __j_internal!{ $( $body)* } };
            __j_internal!{ $($rest)* }
        };

        // do { .. } while !c;
        ( do { $( $body: tt )* } while ! $c: ident; $($rest:tt)* ) => {
            while { __j_internal!{ $( $body)* }; ! $c.val } { };
            __j_internal!{ $($rest)* }
        };

        // do { .. } while c;
        ( do { $( $body: tt )* } while $c: ident; $($rest:tt)* ) => {
            while { __j_internal!{ $( $body)* }; $c.val } { };
            __j_internal!{ $($rest)* }
        };

        // if .. { .. } else { .. }
        ( if ( $c: expr ) { $( $body: tt )* } else { $( $ebody: tt )* } $($rest:tt)* ) => {
            if $c { __j_internal!{ $( $body )* } } else { __j_internal!{ $( $ebody )* } } ;
            __j_internal!{ $($rest)* }
        };

        // if .. { .. }
        ( if ( $c: expr ) { $( $body: tt )* } $($rest:tt)* ) => {
            if $c { __j_internal!{ $( $body)* } };
            __j_internal!{ $($rest)* }
        };

        // embed rust only instructions

        // rust code ignored by compiler
        ( rust! { $( $body: tt )* } $($rest:tt)* ) => {
            { $( $body)* };
            __j_internal!{ $($rest)* }
        };

        // everything else, e.g. function calls for void functions
        ( $e: expr ; $($rest:tt)* ) => {
            $e;
            __j_internal!{ $($rest)* }
        };

    }

    #[macro_export]
    macro_rules! rust {
        ( $( $d: tt )* ) => {
            $( $d )*
        }
    }

    #[macro_export]
    macro_rules! reg {
        ( $( $d: tt )* ) => {
            $( $d )*
        }
    }

    #[macro_export]
    macro_rules! stack {
        ( $( $d: tt )* ) => {
            $( $d )*
        }
    }
}

// 
#[allow(non_snake_case)]
pub mod U64 {
    use extprim::traits::ToExtraPrimitive;

    use jasmin::*;

    const fn jv<T>(x: T) -> Jval<T> {
        Jval {val: x}
    }

    // we use ToJval<u64> to allow for u64 constants
    pub fn add_v<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val.wrapping_add(y.val))
    }

    pub fn add<T1,T2>(x: T1, y: T2) -> (b1,b64) 
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        let (r,cf) = x.val.overflowing_add(y.val);
        (jv(cf),jv(r))
    }

    pub fn adc_v<T1,T2,T3>(x: T1, y: T2, cf: T3) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64>, T3: ToJval<bool> {
        let (x,y,cf) = (x.to_jval(), y.to_jval(),cf.to_jval());
        jv(x.val.wrapping_add(y.val).wrapping_add(cf.val as u64))
    }

    pub fn adc<T1,T2,T3>(x: T1, y: T2, cf: T3) -> (b1,b64)
      where T1: ToJval<u64>,T2: ToJval<u64>, T3: ToJval<bool> {
        let (x,y,cf) = (x.to_jval(), y.to_jval(),cf.to_jval());
        let (r,cf1) = x.val.overflowing_add(y.val);
        let (r,cf2) = r.overflowing_add(cf.val as u64);
        (jv(cf1 || cf2),jv(r))
    }


    pub fn sub_v<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val.wrapping_sub(y.val))
    }

    pub fn sub<T1,T2>(x: T1, y: T2) -> (b1,b64)
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        let (r,cf) = x.val.overflowing_sub(y.val);
        (jv(cf),jv(r))
    }


    pub fn sbb_v<T1,T2,T3>(x: T1, y: T2, cf: T3) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64>, T3: ToJval<bool> {
        let (x,y,cf) = (x.to_jval(), y.to_jval(),cf.to_jval());
        jv(x.val.wrapping_sub(y.val).wrapping_sub(cf.val as u64))
    }

    pub fn sbb<T1,T2,T3>(x: T1, y: T2, cf: T3) -> (b1,b64)
      where T1: ToJval<u64>,T2: ToJval<u64>, T3: ToJval<bool> {
        let (x,y,cf) = (x.to_jval(),y.to_jval(),cf.to_jval());
        let (r,cf1) = x.val.overflowing_sub(y.val);
        let (r,cf2) = r.overflowing_sub(cf.val as u64);
        (jv(cf1 || cf2),jv(r))
    }

    pub fn mul<T1,T2>(x: T1, y: T2) -> (b64, b64)
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        let z = x.val.to_u128().unwrap() * y.val.to_u128().unwrap();
        (jv(z.high64()), jv(z.low64()))
    }

    pub fn imul<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        let z = x.val.to_u128().unwrap() * y.val.to_u128().unwrap();
        jv(z.low64())
    }

    pub fn xor<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val ^ y.val)
    }

    pub fn land<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val & y.val)
    }

    pub fn lor<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val | y.val)
    }

    pub fn shr<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val >> y.val)
    }

    pub fn shl<T1,T2>(x: T1, y: T2) -> b64
      where T1: ToJval<u64>,T2: ToJval<u64> {
        let (x,y) = (x.to_jval(), y.to_jval());
        jv(x.val << y.val)
    }
}

#[cfg(test)]
mod tests {

    use jasmin::*;
    use jasmin::ToJval;
    use U64::*;


    fn id_array(x: [b64; 10]) -> [b64; 10] {
        x
    }

    fn clear_array(_x: [b64; 10]) { }

    #[test]
    fn test_syntax() {
        #![allow(unused_assignments)]
        #![allow(unused_variables)]

        let mut x    : stack! (b64);
        let mut y    : reg! (b64);
        let mut cf   : reg! (b1);
        let mut _cf  : reg! (b1);
        let mut arr1 : reg! ([b64; 10]);
        let mut arr2 : reg! ([b64; 10]);

        code!{
            do {
                arr1 = [0; 10];
                arr2 = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
                x  = #16;
                MEM[x + 0] = x;
                y = #0;
                arr1[y] = #1;
                y = arr1[y];
                for i in (0..4) {
                    MEM[x + i*8] = x;
                }
                for i in (0..4) {
                    x = MEM[x + i*8];
                }      
                x = MEM[x + 0];
                arr1 = id_array(arr1);
                clear_array(arr1);
                cf = #false;
                arr1[0] = #0;
                y  = x;
                cf = cf.val.to_jval();
                (cf,x)  = adc(x,y,cf);
                when cf { x = adc_v(x,y,cf) };
                when !cf { x = adc_v(x,y,false) };
                (_cf,x) = adc(x,y,cf);
                (cf,x)  = add(x,0);
                (cf,y)  = adc(x,y,cf);
                (x,y,cf,_cf) = (x,y,cf,_cf);
                _cf  = cf;
                cf = #false;
            } while cf;
            do {
                (cf,x)  = add(x,y);
                (_cf,x) = adc(x,y,cf);
                (cf,x)  = add(x,y);
                (_cf,y) = adc(x,y,cf);
                cf = #true;
            } while !cf;
            
        };
        println!("x: {}, y: {}, cf: {}", x.val, y.val, cf.val);
    }

    #[test]
    fn test_mem() {
        let mut x    : stack! (b64);
        let     p    : stack! (b64);

        println!("starting test");
        code!{
            p = #8;
            for i in (0..64) {
                x = #(i as u64);
                MEM[p + i*8] = x;
                rust! { println!("writing {} with i={}: ",x.val,i) }
            }
            for i in (0..64) {
                x = MEM[p + i*8];
                rust! {
                    println!("reading {} with i={}: ",x.val,i);
                    assert_eq!(x.val, i as u64);
                }
            }

        }
    }
}
