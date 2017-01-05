(* * Prove properties about semantics of dmasm input language *)

(* ** Imports and settings *)
Require Import JMeq ZArith Setoid Morphisms.
From mathcomp Require Import ssreflect ssrfun ssrbool ssrnat ssrint ssralg.
From mathcomp Require Import choice fintype eqtype div seq zmodp finset.
Require Import Coq.Logic.Eqdep_dec.
Require Import strings word dmasm_utils dmasm_type dmasm_var dmasm_expr memory dmasm_sem.
Require Import allocation compiler_util.

Set Implicit Arguments.
Unset Strict Implicit.
Unset Printing Implicit Defensive.

Local Open Scope vmap.

Local Open Scope seq_scope.

Module CmpIndex.

  Definition t := [eqType of (var * Z)%type].

  Definition cmp : t -> t -> comparison := 
    lex CmpVar.cmp Z.compare.

  Lemma cmpO : Cmp cmp.
  Proof. apply LexO;[apply CmpVar.cmpO|apply ZO]. Qed.

End CmpIndex.

Local Notation index:= (var * Z)%type.

Module Mi := gen_map.Mmake CmpIndex.

Module Ma := MakeMalloc Mi.

Module CBEA.

  Module M.

    Definition valid (alloc: Ma.t) (allocated:Sv.t) := 
      forall x n id, Ma.get alloc (x,n) = Some id -> 
        Sv.In x allocated /\ Sv.In ({|vtype := sword; vname := id |}) allocated. 

    Record expansion := mkExpansion {
      initvar   : Sv.t;  
      alloc     : Ma.t;
      allocated : Sv.t;
      Valid     : valid alloc allocated
    }.

    Definition t := expansion.

    Lemma valid_empty : valid Ma.empty Sv.empty.
    Proof. by move=> x n id;rewrite Ma.get0. Qed.

    Definition empty := mkExpansion Sv.empty valid_empty.

    Lemma valid_merge r1 r2 : 
       valid (Ma.merge (alloc r1) (alloc r2)) 
             (Sv.inter (allocated r1) (allocated r2)).
    Proof.
      by move=> x n id => /Ma.mergeP [] /(@Valid r1)[??]/(@Valid r2)[??];SvD.fsetdec.
    Qed.

    Definition merge r1 r2 := 
       mkExpansion (Sv.inter (initvar r1) (initvar r2))
                   (@valid_merge r1 r2).

    Definition incl r1 r2 :=
      Ma.incl (alloc r1) (alloc r2) && Sv.subset (initvar r1) (initvar r2).              

    Lemma incl_refl r: incl r r.
    Proof. rewrite /incl Ma.incl_refl /=;apply SvP.subset_refl. Qed.

    Lemma incl_trans r2 r1 r3: incl r1 r2 -> incl r2 r3 -> incl r1 r3.
    Proof. 
      rewrite /incl=> /andP[]Hi1 Hs1 /andP[] Hi2 Hs2.
      rewrite (Ma.incl_trans Hi1 Hi2) /=.
      apply: SvP.subset_trans Hs1 Hs2.
    Qed.

    Lemma merge_incl_l r1 r2: incl (merge r1 r2) r1.
    Proof. by rewrite /incl /merge /= Ma.merge_incl_l SvP.inter_subset_1. Qed.

    Lemma merge_incl_r r1 r2: incl (merge r1 r2) r2.
    Proof. by rewrite /incl /merge /= Ma.merge_incl_r SvP.inter_subset_2. Qed.

    Lemma valid_set_arr x nx id r:
      valid (Ma.set (alloc r) (x,nx) id) 
         (Sv.add {|vtype := sword; vname := id|} (Sv.add x (allocated r))).
    Proof.
      move=> y ny idy.
      case: ((x,nx) =P (y,ny)) => [[]<- <-|Hne]. 
      + by rewrite Ma.setP_eq=> -[] <-;SvD.fsetdec.
      move=> /Ma.setP_neq [];first by apply /eqP.
      by move=> /Valid []??;SvD.fsetdec.
    Qed.

    Definition set_arr x N id r := mkExpansion (initvar r) (@valid_set_arr x N id r).

    Definition set_var x r := mkExpansion (Sv.add x (initvar r)) (@Valid r).

  End M.

(*
  Definition eq_alloc (r:M.t) (vm vm':vmap) :=
    (forall x, Sv.In x (M.initvar r) -> val_uincl vm.[x] vm'.[x]) /\
    (forall x n id, Ma.get (M.alloc r) (x,tobase n) = Some id ->
     match x with
     | Var (sarr s) id' => 
       let x := Var (sarr s) id' in
       let x' := Var sword id in 
       @Array.get _ s vm.[x] (I64.repr n) = ok vm'.[x']
     | _ => False
     end).
 
  Lemma eq_alloc_empty vm: all_empty_arr vm -> eq_alloc M.empty vm vm.
  Proof. by move=> _;rewrite /M.empty /eq_alloc. Qed.

  Lemma eq_alloc_incl r1 r2 vm vm':
    M.incl r2 r1 -> 
    eq_alloc r1 vm vm' -> 
    eq_alloc r2 vm vm'. 
  Proof.
    move=> /andP[] Hincl /Sv.subset_spec Hsub [] Hv Ha;split.
    + move=> x Hx;apply Hv;SvD.fsetdec.
    by move=> x n id /(Ma.inclP _ _ Hincl) /Ha.
  Qed.

  Definition is_oget t1 t2 tr (o:sop2 t1 t2 tr) := 
    match o with
    | Oget _ => true
    | _      => false
    end.
*)

  Definition check_var m x1 e1 x2 := 
    match is_const e1 with
    | Some n1 => (Ma.get (M.alloc m) (x1.(v_var), tobase n1) == Some (vname x2)) &&
                  (vtype x2 == sword)
    | _ => false
    end.

  Fixpoint check_eb m (e1 e2:pexpr) : bool := 
    match e1, e2 with
    | Pconst   n1, Pconst   n2 => n1 == n2
    | Pbool    b1, Pbool    b2 => b1 == b2
    | Pcast    e1, Pcast    e2 => check_eb m e1 e2
    | Pvar     x1, Pvar     x2 => (x1.(v_var) == x2) && Sv.mem x1 (M.initvar m)
    | Pget  x1 e1, Pget  x2 e2 => 
      (x1.(v_var) == x2) && Sv.mem x1 (M.initvar m) && check_eb m e1 e2
    | Pget  x1 e1, Pvar  x2    => check_var m x1 e1 x2
    | Pload x1 e1, Pload x2 e2 => 
      (x1.(v_var) == x2) && Sv.mem x1 (M.initvar m) && check_eb m e1 e2
    | Pnot     e1, Pnot     e2 => check_eb m e1 e2
    | Papp2 o1 e11 e12, Papp2 o2 e21 e22 =>    
      (o1 == o2) && check_eb m e11 e21 && check_eb m e12 e22
    | _, _ => false
    end.

  Definition check_e (e1 e2:pexpr) m := 
    if check_eb m e1 e2 then cok m else cerror (Cerr_arr_exp e1 e2). 

  Definition check_rval_aux mi (r1 r2:rval) m := 
    match r1, r2 with 
    | Rnone _, Rnone _ => cok m
    | Rvar x1, Rvar x2 => 
      if (x1.(v_var) == x2) && ~~Sv.mem x1 (M.allocated m) then cok (M.set_var x1 m) 
      else cerror (Cerr_arr_exp_v r1 r2)
    | Rmem x1 e1, Rmem x2 e2 =>
      if  (x1.(v_var) == x2) && Sv.mem x1 (M.initvar mi) && check_eb mi e1 e2 then cok m
      else cerror (Cerr_arr_exp_v r1 r2)
    | Raset x1 e1, Rvar x2 =>
      if Sv.mem x1 (M.initvar m) || Sv.mem x2 (M.initvar m) then cerror (Cerr_arr_exp_v r1 r2)
      else match is_const e1 with 
      | Some n1 => cok (M.set_arr x1 n1 (vname x2) m)
      | None    => cerror (Cerr_arr_exp_v r1 r2)
      end
    | Raset x1 e1, Raset x2 e2 =>
      if (x1.(v_var) == x2) && check_eb mi e1 e2 && ~~Sv.mem x1 (M.allocated m) then 
        cok (M.set_var x1 m)
      else cerror (Cerr_arr_exp_v r1 r2)
    | _, _ => cerror (Cerr_arr_exp_v r1 r2)
    end.

  Definition check_rval (r1 r2:rval) m := check_rval_aux m r1 r2 m.

  Definition fold2_error := Cerr_fold2 "array_expansion:check_rval".

  Definition check_rvals xs1 xs2 m := fold2 fold2_error (check_rval_aux m) xs1 xs2 m.

(* 
  Definition check_bcmd t1 (x1:rval t1) (e1:pexpr t1) t2 (x2:rval t2) (e2:pexpr t2) m := 
    match check_imm_set x1 e1 x2 e2 m with 
    | Error _ => 
      if check_eb m e1 e2 then check_rval x1 x2 m
      else Error tt
    | res => res
    end.
    
  Lemma is_ogetP t1 t2 tr (o:sop2 t1 t2 tr): 
    is_oget o -> 
    exists n, [/\ t1 = (sarr n), t2=sword, tr=sword &
                  JMeq o (Oget n)].
  Proof. by case:o => //= n;exists n;split. Qed.

  Lemma check_varP r t1 (e1:pexpr t1) t2 (e2:pexpr t2) x2:
    check_var r e1 e2 x2 ->
    exists x1 n2, [/\ t1 = vtype x1, t2 = sword, 
                   JMeq e1 (Pvar x1) , JMeq e2 (Pconst n2) & (vtype x2 = sword) /\
                   (Ma.get (M.alloc r) (x1, tobase n2) = Some (vname x2))].
  Proof. 
    by case: e1 e2 => // x1 [] //= n2 /andP[]/eqP ? /eqP ?;exists x1, n2;split. 
  Qed.

  Lemma check_eb_eqt r t1 (e1:pexpr t1) t2 (e2:pexpr t2):
    check_eb r e1 e2 -> t1 = t2.
  Proof.
   elim: e1 t2 e2 =>
      [ x1 | e1 He1 | n1 | b1 | ?? o1 e1 He1
      | ??? o1 e11 He1 e12 He2 | ???? o1 e11 He1 e12 He2 e13 He3] t2
      [ x2 | e2 | n2 | b2 | ?? o2 e2
      | ??? o2 e21  e22 | ???? o2 e21 e22 e23] //=.
    + by move=> /andP []/eqP->.
    + by move=> /andP[] Ho /He1 Heqt;case:(eqb_sop1P Heqt Ho).
    + move=> /andP[] /is_ogetP [n [??? Hjm]];subst.
      by move=> /check_varP [x1 [n2 ]] [] ???? [] ->.
    + by move=> /andP[]/andP[] Ho /He1 H1 /He2 H2;case:(eqb_sop2P H1 H2 Ho).
    by move=> /andP[]/andP[]/andP[] Ho /He1 H1 /He2 H2 /He3 H3;case:(eqb_sop3P H1 H2 H3 Ho).
  Qed.    

  Lemma check_e_eqt r r' t1 (e1:pexpr t1) t2 (e2:pexpr t2):
    check_e e1 e2 r = Ok unit r' -> t1 = t2.
  Proof. by rewrite /check_e;case:ifP => //= /check_eb_eqt. Qed.

  Lemma check_ebP_aux t1 (e1:pexpr t1) t2 (e2: pexpr t2) r m1 vm1 vm2: 
    eq_alloc r vm1 vm2 ->
    check_eb r e1 e2 ->
    forall v1,  sem_pexpr {|emem := m1; evm:= vm1|} e1 = ok v1 ->
    exists v2, sem_pexpr {|emem := m1; evm:= vm2 |} e2 = ok v2 /\ val_uincl2 v1 v2.
  Proof.
    move=> Hrn; elim: e1 t2 e2 =>
      [ [tx1 x1] | e1 He1 | n1 | b1 | ?? o1 e1 He1
      | ??? o1 e11 He1 e12 He2 | ???? o1 e11 He1 e12 He2 e13 He3] t2
      [ [tx2 x2] | e2 | n2 | b2 | ?? o2 e2
      | ??? o2 e21  e22 | ???? o2 e21 e22 e23] //=.
    + move=> /andP[]/eqP[]<- <-;rewrite /is_true -SvD.F.mem_iff.
      by case : Hrn=> H _ /H /val_uincl2P Hu ? [] <-;eauto.
    + move=> /He1{He1}He1 v1;case Heq: sem_pexpr => [v|]//=.
      by case (He1 _ Heq) => v' [] -> /= <- ?;exists v1.
    + by move=> /eqP -> ? [] <-;eauto.
    + by move=> /eqP -> ? [] <-;eauto.
    + move=> /andP[] Ho H1.  
      have ? := check_eb_eqt H1;subst.
      case:(eqb_sop1P _ Ho) => // ?;subst=> -> v1.
      case Heq1:(sem_pexpr _ e1) => [v1'|]//=.
      case: (He1 _ _ H1 _ Heq1)=> v2' [He2 /val_uincl2P Hu2].  
      by move=> /(sem_sop1_uincl Hu2) [v2 [Hs Hu]];exists v2;rewrite He2 -val_uincl2P.
    + move=> /andP[] /is_ogetP [n [??? Hjm]];subst.
      move=> /check_varP [[tx1 x1] [n2 ]] [] /= ??;subst=> H1 H2.
      have {H1}H1:= JMeq_eq H1;have {H2}H2:= JMeq_eq H2 => -[] ?;subst=> /=.
      case Hrn=> _ H /H /= -> v1 [] <-;eauto.
    + move=> /andP[]/andP[] Ho H1 H2.
      have ? := check_eb_eqt H1;subst; have ? := check_eb_eqt H2;subst=>v.
      case:(eqb_sop2P _ _ Ho) => // ?;subst=> ->.
      case Heq1:(sem_pexpr _ e11) => [v1|]//=.
      case Heq2:(sem_pexpr _ e12) => [v2|]//=. 
      case: (He1 _ _ H1 _ Heq1)=> v1' [Hs1 /val_uincl2P Hu1]. 
      case: (He2 _ _ H2 _ Heq2)=> v2' [Hs2 /val_uincl2P Hu2]. 
      by move=> /(sem_sop2_uincl Hu1 Hu2) [v' [Hs Hu]];exists v';rewrite Hs1 Hs2 -val_uincl2P.
    move=> /andP[]/andP[]/andP[] Ho H1 H2 H3.
    have ? := check_eb_eqt H1;subst; have ? := check_eb_eqt H2;have ? := check_eb_eqt H3.
    subst=>v.
    case:(eqb_sop3P _ _ _ Ho) => // ?;subst=> ->.
    case Heq1:(sem_pexpr _ e11) => [v1|]//=.
    case Heq2:(sem_pexpr _ e12) => [v2|]//=. 
    case Heq3:(sem_pexpr _ e13) => [v3|]//=. 
    case: (He1 _ _ H1 _ Heq1)=> v1' [Hs1 /val_uincl2P Hu1]. 
    case: (He2 _ _ H2 _ Heq2)=> v2' [Hs2 /val_uincl2P Hu2]. 
    case: (He3 _ _ H3 _ Heq3)=> v3' [Hs3 /val_uincl2P Hu3]. 
    move=> /(sem_sop3_uincl Hu1 Hu2 Hu3) [v' [Hs Hu]].
    by exists v';rewrite Hs1 Hs2 Hs3 -val_uincl2P.
  Qed.

  Lemma check_eP_aux: forall t1 (e1:pexpr t1) t2 (e2: pexpr t2) r re m1 vm1 vm2, 
    check_e e1 e2 r = Ok unit re ->
    eq_alloc r vm1 vm2 ->
    eq_alloc re vm1 vm2 /\
    forall v1,  sem_pexpr {|emem := m1; evm := vm1|} e1 = ok v1 ->
    exists v2, sem_pexpr {|emem := m1; evm := vm2|} e2 = ok v2 /\ val_uincl2 v1 v2.
  Proof.
    rewrite /check_e=> t1 e1 t2 r2 r re m1 vm1 vm2 Hc Heqa.
    case:ifP Hc => //= Hc [] <-;split=>//.
    by apply: (check_ebP_aux Heqa). 
  Qed.

  Lemma check_rvalb_eqt t1 t2 r1 (rv1:rval t1) (rv2:rval t2):
    check_rvalb rv1 rv2 r1 ->
    t1 = t2.
  Proof.
    elim: rv1 t2 rv2 => [x1 | e1 | ?? x11 Hx1 x12 Hx2] t2 [x2 | e2 | ?? x21 x22] //=.
    + by move=> /eqP <-.
    by case Heq: check_rvalb => //= /Hx1 ->;rewrite (Hx2 _ _ Heq).
  Qed.    
 
  Lemma check_rval_aux_eqt t1 t2 r1 r2 (rv1:rval t1) (rv2:rval t2):
    check_rval_aux rv1 rv2 r1 = Ok unit r2 ->
    t1 = t2.
  Proof.
    elim: rv1 t2 rv2 r1 r2 => [x1 | e1 | ?? x11 Hx1 x12 Hx2] t2 [x2 | e2 | ?? x21 x22] //= r1 r2.
    + by case:andP => [[]/eqP->|].
    case Heq: check_rval_aux => [r'|] //= /Hx1 ->.
    by rewrite (Hx2 _ _ _ _ Heq).
  Qed.    

  Lemma check_rval_eqt t1 t2 r1 r2 (rv1:rval t1) (rv2:rval t2):
    check_rval rv1 rv2 r1 = Ok unit r2 ->
    t1 = t2.
  Proof.
    rewrite /check_rval;case: check_rvalb (@check_rvalb_eqt _ _ r1 rv1 rv2) => // H _.
    by rewrite H.
  Qed.

  Lemma check_rvalb_rval2 t1 (rv1:rval t1) t2 (rv2:rval t2) r1 m vm vm' vr1:
    eq_alloc r1 vm vm' ->
    check_rvalb rv1 rv2 r1 ->
    rval2vval {| emem := m; evm := vm |} rv1 = ok vr1 ->
    exists vr2 : vval t2,
      [/\ rval2vval {| emem := m; evm := vm' |} rv2 = ok vr2
        & JMeq vr1 vr2].
  Proof.
    move=> eqa; elim: rv1 t2 rv2 vr1=> 
     [x1|e1|?? x11 Hx1 x12 Hx2] t2 [x2|e2| ?? x21 x22] vr1=> //=.  
    + by move=> /eqP <- [] <-;exists (Vvar x1).
    + move=> Hc;case Heq: sem_pexpr => [v1|] //= [] <-.
      by have [v2 [-> <-]] /= := check_ebP_aux eqa Hc Heq;exists (Vmem v1).
    move=> /andP[] Hc2 Hc1.
    case Heq1: (rval2vval _ x11) => [v1|] //=.
    case Heq2: (rval2vval _ x12) => [v2|] //= [] <-.
    have ? := check_rvalb_eqt Hc1; have ?:= check_rvalb_eqt Hc2;subst.
    have [v12 {Heq1}[-> Heq1] ]:= Hx1 _ _ _ Hc1 Heq1. 
    have [v22 {Heq2}[-> Heq2] ] /= := Hx2 _ _ _ Hc2 Heq2;subst v12 v22.
    by exists (Vpair v1 v2).
  Qed.
  
  Lemma eq_write_aux t1 (rv1:rval t1) t2 (rv2:rval t2) v1 v2 r1 r2 m1 m2 vm1 vm1' vm2:
    check_rval rv1 rv2 r1 = Ok unit r2 ->
    eq_alloc r1 vm1 vm1' ->
    val_uincl2 v1 v2 ->
    write_rval {|emem := m1;evm:= vm1|} rv1 v1 = ok {|emem := m2;evm:= vm2|} ->
    exists vm2', 
      write_rval {|emem := m1;evm:= vm1'|} rv2 v2 = ok {|emem := m2;evm:= vm2'|} /\
      eq_alloc r2 vm2 vm2'.
  Proof.
    rewrite /write_rval /check_rval;case:ifPn => //= Hrb Hra eqa Hu.
    case Heq : rval2vval => [vr1|] //=. 
    have [vr2 [Hrv2 HJM] {Hrb}] := check_rvalb_rval2 eqa Hrb Heq.
    rewrite Hrv2 /= => {Hrv2}.
    move: {1} {| emem := m1; evm := vm1 |} Heq => m0.
    have Ht := check_rval_aux_eqt Hra.
    move: vr1 vr2 v1 v2 Hu HJM;rewrite -Ht=> vr1 vr2 v1 v2 Hu ?;subst vr2=> {Ht}.
    elim: rv1 t2 rv2 vr1 v1 v2 r1 r2 vm1 vm1' vm2 m1 m2 Hra eqa Hu =>
      [x1|e1|?? x11 Hx1 x12 Hx2] t2 [x2|e2| ?? x21 x22] //= 
      vr1 v1 v2 r1 r2 vm1 vm1' vm2 m1 m2.
    + case: ifP => //= /andP [] _=>  /Sv_memP Hna [] <- [eqa1 eqa2]
       Hu [] <- /= [] <- <-.
      exists vm1'.[x1 <- v2]; split=>//;split=> /=.
      + move=> x;case : (x1 =P x) => [<-|/eqP Hne Hin].
        + by rewrite !Fv.setP_eq val_uincl2P.
        rewrite !Fv.setP_neq //;apply eqa1. 
        by move/eqP: Hne;SvD.fsetdec.
      move=> x n id Hal;case: x Hal (eqa2 _ _ _ Hal) => -[|||s] //= xid Hal Hget.
      by have [??]:= M.Valid Hal;rewrite !Fv.setP_neq //;
       apply /eqP=> H;apply Hna;rewrite H.
    + move=> [] <- eqa <-.
      case: (sem_pexpr _ e1) => [ve1|]//= [] <- /=. 
      by case: write_mem => [m2'|] //= [] -> <-;exists vm1'.
    case Hra2 : check_rval_aux => [r1'|] //= Hra1 eqa [Hu1 Hu2].
    case Hrv1 : (rval2vval _ x11) => [vr11|] //=.
    case Hrv2 : (rval2vval _ x12) => [vr12|] //= [] <- /=.
    case Heq1: write_vval => [[m3 vm3]|] //= Heq2.
    have [vm3' [-> Heqa3]]:=
       Hx2 _ _ _  _ _ _ _  _ _ _ _ _ Hra2 eqa Hu2 Hrv2 Heq1.
    have [vm2' /= [-> Heqa2]]:=
       Hx1 _ _ _  _ _ _ _  _ _ _ _ _ Hra1 Heqa3 Hu1 Hrv1 Heq2.
    by exists vm2'.
  Qed.

  Lemma eq_write t (rv1 rv2:rval t) v1 v2 r1 r2 m1 m2 vm1 vm1' vm2:
    check_rval rv1 rv2 r1 = Ok unit r2 ->
    eq_alloc r1 vm1 vm1' ->
    val_uincl v1 v2 ->
    write_rval {|emem := m1;evm:= vm1|} rv1 v1 = ok {|emem := m2;evm:= vm2|} ->
    exists vm2', 
      write_rval {|emem := m1;evm:= vm1'|} rv2 v2 = ok {|emem := m2;evm:= vm2'|} /\
      eq_alloc r2 vm2 vm2'.
  Proof. by move=> Hc Hrn /val_uincl2P Hu; apply (eq_write_aux Hc). Qed.
 
  Lemma check_imm_setP  t1 (rv1:rval t1) e1 t2 (rv2:rval t2) e2 r1 r2 :
    check_imm_set rv1 e1 rv2 e2 r1 = Ok unit r2 ->
    exists nx1 nx2 n n1 e2',
     let x1 := {| vtype := (sarr n); vname := nx1 |} in
     let x2 := {| vtype := sword; vname := nx2 |} in
     [/\ [/\ t1 = (sarr n), t2 = sword, 
             JMeq rv1 (Rvar x1),
             JMeq rv2 (Rvar x2) &
             JMeq e1 (Papp3 (Oset n) (Pvar x1) (Pconst n1) e2')], 
          check_eb r1 e2' e2, 
          r2 = M.set_arr x1 (tobase n1) (vname x2) r1,
          ~Sv.In x1 (M.initvar r1) &
          ~Sv.In x2 (M.initvar r1)
         ].
  Proof.
    case: rv1 rv2 e1 e2 => //= -[xt1 nx1] [] //= -[xt2 nx2].
    move=> e1 e2;case:ifPn => //=;rewrite negb_or=> /andP[]/negP Hin1 /negP Hin2.
    move: Hin1 Hin2;rewrite /is_true -!SvD.F.mem_iff.
    case: e1 e2 => //= ???? [] //= n p p0 p1 e2.
    case:ifP=> //= /andP[H1 H2].
    case Heq: is_const => [n1|]//= Hin1 Hin2 [] <-.
    rewrite (is_constP Heq);exists nx1, nx2, n, n1, p1.
    have ? := check_eb_eqt H2;subst;split=> //;split=>//.
    have -> //: JMeq p (Pvar {| vtype := sarr n; vname := nx1 |}).
    by move: H1;case: p=> //= x /eqP ->.
  Qed.

  Lemma check_bcmdP i1 r1 i2 r2:
    check_bcmd i1 i2 r1 = Ok unit r2 ->
    forall m1 m2 vm1 vm2, sem_i (Estate m1 vm1) (Cbcmd i1) (Estate m2 vm2) ->
    forall vm1', eq_alloc r1 vm1 vm1' ->
    exists vm2', eq_alloc r2 vm2 vm2' /\ 
    sem_i (Estate m1 vm1') (Cbcmd i2) (Estate m2 vm2').
  Proof.
    case: i1 i2 =>
      [t1 rv1 e1 | rv1 e1 | e11 e12] [t2 rv2 e2 | rv2 e2 | e21 e22] //=.
    + case Himm: check_imm_set => [r1'|] /=. 
      + move=> [] ? m1 m2 vm1 vm2 H vm1' Hvm1;subst r1';sinversion H.
        move:Himm H2=> /= /check_imm_setP [nx1 [nx2 [n [n1 [e2']]]]] /= [] [].
        move=> ??;subst => -> -> -> Hce -> /= Hnin1 Hnin2.
        case He2' : sem_pexpr => [v2'|] //=.
        rewrite /Array.set; case: ifP => [Hbound|] //= [] <- <-.
        exists (vm1'.[{| vtype := sword; vname := nx2 |} <- v2']);split;last first.
        + constructor => /=.
          by have [? [-> /= <-]]:= check_ebP_aux Hvm1 Hce He2'.
        case Hvm1=>Hvm_1 Hvm_2; split=> /=.
        + move=> x Hin;rewrite !Fv.setP_neq;first by apply Hvm_1.
          + by apply /eqP=> Hx;subst;SvD.fsetdec.
          by apply /eqP=> Hx;subst;SvD.fsetdec.
        move=> x n0 id; set x1 := {| vtype := sarr n; vname := nx1 |}.
        case: ((x1,tobase n1) =P (x,tobase n0)) => [[] Hx Hn|/eqP Hneq].
        + subst x;rewrite Hn Ma.setP_eq=> -[] ?;subst=> /=.
          rewrite !Fv.setP_eq; move: Hn Hbound=> /eqP /reqP -> Hbound.
          by rewrite /Array.get Hbound FArray.setP_eq.
        move=> /Ma.setP_neq [] // /Hvm_2.         
        case: x Hneq => -[] //= n2 xn Hneq.
        case: (x1 =P {| vtype := sarr n2; vname := xn |}).
        + move=> [] ??;subst;rewrite /x1 Fv.setP_eq => H1 Hne.
          rewrite /Array.get Fv.setP_neq;last by apply /eqP=> -[].
          rewrite FArray.setP_neq //. 
          by apply: contra Hneq => /eqP /reqP /eqP ->.
        move=> /eqP Hne H1 H2; rewrite !Fv.setP_neq //. 
        by apply /eqP=> -[].
      case: ifP => //= Hce Hcr.
      have ? := check_eb_eqt Hce;subst.
      move=> m1 m2 vm1 vm2 H;sinversion H=> vm1' Hvm1.
      move: H2 => /=;case Heq1: sem_pexpr=> [v1|] //= [] <- <-.
      have [v1' [/= Hs /val_uincl2P Hu]]:= check_ebP_aux Hvm1 Hce Heq1.
      exists (write_rval vm1' rv2 v1');split;first by apply (eq_write Hcr).
      by constructor;rewrite /= Hs.
    + case Hce: check_eb => //= Hcr.
      have ? := check_eb_eqt Hce;subst.
      move=> m1 m2 vm1 vm2 H;inversion H;clear H;subst=> vm1' Hvm1.
      move:H2=> /=;case Heq1: sem_pexpr=> [v1|] //=.
      have [v1' [/= Hs Hu]]:= check_ebP_aux Hvm1 Hce Heq1;subst v1'.
      case Heqr: read_mem=> [w|]//= []<- <-.
      exists (write_rval vm1' rv2 w);split;first by apply (eq_write Hcr).
      by constructor;rewrite /= Hs /= Heqr.
    case:ifP => //= /andP[Hce1 Hce2] [] <- m1 m2 vm1 vm2 H;inversion H;clear H;subst.
    move=> vm1' Hvm1;move:H2=> /=.
    case Heq1: (sem_pexpr vm1 e11) => [v1|]//=.
    case Heq2: sem_pexpr=> [v2|]//=.
    have [v1' [/= Hs1 ?]]:= check_ebP_aux Hvm1 Hce1 Heq1.
    have [v2' [/= Hs2 ?]]:= check_ebP_aux Hvm1 Hce2 Heq2;subst v1' v2'.
    case Heqw: write_mem=> [m2'|]//= []<- <-.
    exists vm1';split=> //.
    by constructor=> /=;rewrite Hs1 Hs2 /= Heqw.
  Qed.
*)
End CBEA.

Module CheckExpansion :=  MakeCheckAlloc CBEA.

