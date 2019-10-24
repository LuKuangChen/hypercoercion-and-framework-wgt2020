open import CEKcc.CastRep

module Simulation
  (Label : Set)
  (LCR : CastRep Label)
  (LCM : Monoid Label LCR)
  (LCS : SurelyLazyD Label LCR)
  (Extras : CastIdIsId Label LCR)
  where

open import Data.Empty using (⊥; ⊥-elim)
open import Relation.Nullary using (Dec; yes; no; ¬_)
open import Data.Nat using (ℕ; suc; zero; _+_)
open import Data.Product using (Σ; _×_ ; Σ-syntax; ∃-syntax)
  renaming (_,_ to ⟨_,_⟩)
open import Relation.Binary.PropositionalEquality using (_≡_; refl; cong; sym; subst)

open import Variables
open import Types
open import Terms Label
open import Observe Label

open import Utilities

import CEKcc.Machine
import CEKcc.Values
import CEKc.Machine
import CEKc.Values

-- instantiate CEKcc

module L where
  open CastRep LCR public
  open SurelyLazyD LCS public
  open Monoid LCM
    renaming (lem-id-l to monoid-id-l; lem-id-r to monoid-id-r; lem-assoc to monoid-assoc)
    public
  open CastIdIsId Extras public

module LV = CEKcc.Values Label L.Cast
module LM = CEKcc.Machine Label LCR

-- instantiate CEKc

import CEKc.TCast
module RC = CEKc.TCast Label
module RV = CEKc.Values Label RC.Cast
module RM = CEKc.Machine Label -- RC.Cast -- RC.cast
module RP = RM.Progress RC.apply-cast
                        RC.cast-dom RC.cast-cod
                        RC.cast-car RC.cast-cdr
                        RC.cast-inl RC.cast-inr

mutual

  data EnvRelate : ∀ {Γ} → LV.Env Γ → RV.Env Γ → Set where
    []  : EnvRelate LV.[] RV.[]
    _∷_ : ∀ {Γ T}
      → {v : LV.Val T}{u : RV.Val T}
      → ValRelate v u
      → {E : LV.Env Γ}{F : RV.Env Γ}
      → EnvRelate E F
      → EnvRelate (LV._∷_ v E) (RV._∷_ u F)

  data ValRelate : ∀ {T} → LV.Val T → RV.Val T → Set where
    inj : ∀ {l}
      → (P : PreType)
      → {v : LV.Val (` P)}
      → {u : RV.Val (` P)}
      → ValRelate v u
      ----------------
      → ValRelate (LV.inj _ v) (RV.cast u (P⌣⋆ P) (RC.mk-cast l (` P) ⋆))
      
    fun : ∀ {Γ T1 T2}
      → {lE : LV.Env Γ}
      → {rE : RV.Env Γ}
      → (E : EnvRelate lE rE)
      → (b : Γ , T1 ⊢ T2)
      ----
      → ValRelate (LV.fun lE (L.mk-id T1) b (L.mk-id T2)) (RV.fun rE b)
      
    cast-fun : ∀ {Γ T1 T2}
      → ∀ l T3 T4 T5 T6
      → (E : LV.Env Γ)
      → (c1 : L.Cast T3 T1)
      → (b  : Γ , T1 ⊢ T2)
      → (c2 : L.Cast T2 T4)
      → {g : RV.Val (` T3 ⇒ T4)}
      → ValRelate (LV.fun E c1 b c2) g
      ---
      → ValRelate (LV.fun E (L.mk-seq (L.mk-cast l T5 T3) c1) b (L.mk-seq c2 (L.mk-cast l T4 T6)))
                  (RV.cast g ⌣⇒ (RC.mk-cast l (` T3 ⇒ T4) (` T5 ⇒ T6)))      
    sole :
      --------
        ValRelate LV.sole RV.sole

    cast-sole : ∀ {l}
      → {rv : RV.Val (` U)}
      -------
      → ValRelate LV.sole (RV.cast rv ⌣U (RC.mk-cast l (` U) (` U)))

    cons : ∀ {T1 T2}
      → {v1 : LV.Val T1}
      → {u1 : RV.Val T1}
      → ValRelate v1 u1
      → {v2 : LV.Val T2}
      → {u2 : RV.Val T2}
      → ValRelate v2 u2
      ------------------
      → ValRelate (LV.cons v1 (L.mk-id T1) v2 (L.mk-id T2)) (RV.cons u1 u2)

    cast-cons : ∀ {T1 T2}
      → (l : Label)
      → ∀ T3 T4 T5 T6
      → (v1 : LV.Val T1)
      → (c1 : L.Cast T1 T3)
      → (v2 : LV.Val T2)
      → (c2 : L.Cast T2 T4)
      → {u : RV.Val (` T3 ⊗ T4)}
      → ValRelate (LV.cons v1 c1 v2 c2) u
      ------------------
      → ValRelate (LV.cons v1 (L.mk-seq c1 (L.mk-cast l T3 T5))
                           v2 (L.mk-seq c2 (L.mk-cast l T4 T6)))
                  (RV.cast u ⌣⊗ (RC.mk-cast l (` T3 ⊗ T4) (` T5 ⊗ T6)))
      
    inl : ∀ {T1 T2}
      → {lv : LV.Val T1}
      → {rv : RV.Val T1}
      → ValRelate lv rv
      -----------------
      → ValRelate (LV.inl {T2 = T2} lv (L.mk-id T1)) (RV.inl rv)

    cast-inl : ∀ {T1 T3 T4 T5 T6}
      → (lv : LV.Val T1)
      → (lc : L.Cast T1 T3)
      → {rv : RV.Val (` T3 ⊕ T4)}
      → ValRelate (LV.inl lv lc) rv
      → (l : Label)
      -----------------
      → ValRelate (LV.inl lv (L.mk-seq lc (L.mk-cast l T3 T5)))
                  (RV.cast rv ⌣⊕ (RC.mk-cast l (` T3 ⊕ T4) (` T5 ⊕ T6)))
      
    inr : ∀ {T1 T2}
      → {lv : LV.Val T2}
      → {rv : RV.Val T2}
      → ValRelate lv rv
      -----------------
      → ValRelate (LV.inr {T1 = T1} lv (L.mk-id T2)) (RV.inr rv)

    cast-inr : ∀ {T2 T3 T4 T5 T6}
      → (lv : LV.Val T2)
      → (lc : L.Cast T2 T4)
      → {rv : RV.Val (` T3 ⊕ T4)}
      → ValRelate (LV.inr lv lc) rv
      → (l : Label)
      -----------------
      → ValRelate (LV.inr lv (L.mk-seq lc (L.mk-cast l T4 T6)))
                  (RV.cast rv ⌣⊕ (RC.mk-cast l (` T3 ⊕ T4) (` T5 ⊕ T6)))
      
                 
lenv : ∀ {T}
  → {v : LV.Env T}
  → {u : RV.Env T}
  → EnvRelate v u
  → LV.Env T
lenv {v = v} vr = v

renv : ∀ {T}
  → {v : LV.Env T}
  → {u : RV.Env T}
  → EnvRelate v u
  → RV.Env T
renv {u = u} vr = u

lval : ∀ {T}
  → {v : LV.Val T}
  → {u : RV.Val T}
  → ValRelate v u
  → LV.Val T
lval {v = v} vr = v

rval : ∀ {T}
  → {v : LV.Val T}
  → {u : RV.Val T}
  → ValRelate v u
  → RV.Val T
rval {u = u} vr = u

_[_] : ∀ {Γ T}
  → {lE : LV.Env Γ}
  → {rE : RV.Env Γ}
  → (E : EnvRelate lE rE)
  → (x : Γ ∋ T)
  → ValRelate (lE LV.[ x ]) (rE RV.[ x ])
(c ∷ E) [ Z ] = c
(c ∷ E) [ S x ] = E [ x ]

data CastRelate : {T1 T2 : Type} → L.Cast T1 T2 → RC.Cast T1 T2 → Set where
  cast : ∀ l T1 T2
    → CastRelate (L.mk-cast l T1 T2) (RC.mk-cast l T1 T2)

data CastResultRelate {T : Type} : LV.CastResult T → RV.CastResult T → Set where
  succ :
      {v : LV.Val T}{u : RV.Val T}
    → ValRelate v u
    → CastResultRelate (LV.succ v) (RV.succ u)
  fail : (l : Label)
    → CastResultRelate (LV.fail l) (RV.fail l)

do-cast :
    (l : Label)
  → (T1 T2 : Type)
  → {lv : LV.Val T1}
  → {rv : RV.Val T1}
  → ValRelate lv rv
  → CastResultRelate (L.apply-cast (L.mk-cast l T1 T2) lv) (RC.do-cast l T1 T2 rv)
do-cast l T1 T2 v with T1 ⌣? T2
do-cast l .⋆ .⋆ v | yes ⋆⌣⋆
  rewrite L.lem-cast-id⋆ l (lval v)
  = succ v
do-cast l .⋆ .(` P) (inj P₁ v) | yes (⋆⌣P P)
  rewrite L.lem-cast-proj l P P₁ (lval v)
  = do-cast l (` P₁) (` P) v
do-cast l .(` P) .⋆ v | yes (P⌣⋆ P)
  rewrite L.lem-cast-inj l (lval v)
  = succ (inj P v)
do-cast l .(` U) .(` U) sole | yes ⌣U
  rewrite L.lem-cast-U l
  = succ cast-sole
do-cast l .(` U) .(` U) cast-sole | yes ⌣U
  rewrite L.lem-cast-U l
  = succ cast-sole
do-cast l (` T1 ⇒ T2) (` T3 ⇒ T4) (fun E b) | yes ⌣⇒
  rewrite L.lem-cast-⇒ T1 T2 T3 T4 l (lenv E) (L.mk-id _) b (L.mk-id _)
  = succ (cast-fun l T1 T2 T3 T4 _ _ _ _ (fun E b))
do-cast l (` T1 ⇒ T2) (` T3 ⇒ T4) (cast-fun l₁ T5 T6 _ _ lE c1 b c2 f) | yes ⌣⇒
  rewrite L.lem-cast-⇒ T1 T2 T3 T4 l lE
                       (L.mk-seq (L.mk-cast l₁ _ _) c1) b (L.mk-seq c2 (L.mk-cast l₁ _ _))
  = succ (cast-fun l T1 T2 T3 T4 lE _ b _ (cast-fun l₁ T5 T6 _ _ lE _ b _ f))
do-cast l (` (T1 ⊗ T2)) (` (T3 ⊗ T4)) v | yes ⌣⊗ with (lval v)
... | (LV.cons v1 c1 v2 c2)
  rewrite L.lem-cast-⊗ _ _ T1 T2 T3 T4 l v1 v2 c1 c2
  = succ (cast-cons l _ _ _ _ _ _ _ _ v)
do-cast l (` (T1 ⊕ T2)) (` (T3 ⊕ T4)) v | yes ⌣⊕ with (lval v)
... | LV.inl lv lc
  rewrite L.lem-cast-⊕-l _ T1 T2 T3 T4 l lv lc
  = succ (cast-inl _ _ v l)
... | LV.inr lv lc
  rewrite L.lem-cast-⊕-r _ T1 T2 T3 T4 l lv lc
  = succ (cast-inr _ _ v l)
do-cast l T1 T2 v | no ¬p
  rewrite L.lem-cast-¬⌣ l ¬p (lval v)
   = fail l

apply-cast : ∀ {T1 T2}
  → {lc : L.Cast T1 T2}
  → {rc : RC.Cast T1 T2}
  → CastRelate lc rc
  → {lv : LV.Val T1}
  → {rv : RV.Val T1}
  → ValRelate lv rv
  → CastResultRelate (L.apply-cast lc lv) (RC.apply-cast rc rv)
apply-cast (cast l T1 T2) v
  with L.apply-cast (L.mk-cast l T1 T2) (lval v) | RC.do-cast l T1 T2 (rval v) | do-cast l T1 T2 v
... | LV.succ _ | RV.succ _ | succ u = succ u
... | LV.fail _ | RV.fail _ | fail l₁ = fail l₁

mutual
  data ContRelate : {T1 T3 : Type} → LM.Cont T1 T3 → RM.Cont T1 T3 → Set where
    mk-cont : ∀ {T1 T2}
      → {lk : LM.PreCont T1 T2}
      → {rk : RM.Cont T1 T2}
      → (k : PreContRelate lk rk)
      ---
      → ContRelate (LM.mk-cont lk) rk

    ext-cont : ∀ {T2}
      → (l : Label)
      → ∀ T0 T1
      → {lk : LM.Cont T1 T2}
      → {rk : RM.Cont T1 T2}
      → (k : ContRelate lk rk)
      ---
      → ContRelate (LM.ext-cont (L.mk-cast l T0 T1) lk)
                   (RM.cast (RC.mk-cast l T0 T1) rk)
  
  data PreContRelate : {T1 T3 : Type} → LM.PreCont T1 T3 → RM.Cont T1 T3 → Set where
    mt : ∀ {Z}
      ----------
      → PreContRelate ( (LM.mt {Z})) (RM.mt {Z})
  
    cons₁ : ∀ {Γ T1 T2 Z}
      → {lE : LV.Env Γ}
      → {rE : RV.Env Γ}
      → (E : EnvRelate lE rE)
      → (e1 : Γ ⊢ T2)
      → {lκ : LM.Cont (` T1 ⊗ T2) Z}
      → {rκ : RM.Cont (` T1 ⊗ T2) Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.cons₁ lE e1 lκ)) (RM.cons₁ rE e1 rκ)
      
    cons₂ : ∀ {T1 T2 Z}
      → {lv1 : LV.Val T1}
      → {rv1 : RV.Val T1}
      → (v1 : ValRelate lv1 rv1)
      → {lκ : LM.Cont (` T1 ⊗ T2) Z}
      → {rκ : RM.Cont (` T1 ⊗ T2) Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.cons₂ lv1 lκ)) (RM.cons₂ rv1 rκ)
                                                         
    inl :  ∀ {T1 T2 Z}
      → {lκ : LM.Cont (` T1 ⊕ T2) Z}
      → {rκ : RM.Cont (` T1 ⊕ T2) Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.inl lκ)) (RM.inl rκ)
                                             
    inr :  ∀ {T1 T2 Z}
      → {lκ : LM.Cont (` T1 ⊕ T2) Z}
      → {rκ : RM.Cont (` T1 ⊕ T2) Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.inr lκ)) (RM.inr rκ)
        
    app₁ : ∀ {Γ T1 T2 Z}
      → {lE : LV.Env Γ}
      → {rE : RV.Env Γ}
      → (E : EnvRelate lE rE)
      → (e2 : Γ ⊢ T1)
      → {lκ : LM.Cont T2 Z}
      → {rκ : RM.Cont T2 Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.app₁ lE e2 lκ)) (RM.app₁ rE e2 rκ)
                                                           
    app₂ : ∀ {T1 T2 Z}
      → {lv1 : LV.Val (` T1 ⇒ T2)}
      → {rv1 : RV.Val (` T1 ⇒ T2)}
      → (v1 : ValRelate lv1 rv1)
      → {lκ : LM.Cont T2 Z}
      → {rκ : RM.Cont T2 Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.app₂ lv1 lκ)) (RM.app₂ rv1 rκ)
                                                       
    car : ∀ {T1 T2 Z}
      → {lκ : LM.Cont T1 Z}
      → {rκ : RM.Cont T1 Z}
      → (κ : ContRelate lκ rκ)
      -----------
      → PreContRelate ( (LM.car {T2 = T2} lκ)) (RM.car {T2 = T2} rκ)
      
    cdr : ∀ {T1 T2 Z}
      → {lκ : LM.Cont T2 Z}
      → {rκ : RM.Cont T2 Z}
      → (κ : ContRelate lκ rκ)
      -----------
      → PreContRelate ( (LM.cdr {T1 = T1} lκ)) (RM.cdr {T1 = T1} rκ)
      
    case₁ :  ∀ {Γ T1 T2 T3 Z}
      → {lE : LV.Env Γ}
      → {rE : RV.Env Γ}
      → (E : EnvRelate lE rE)
      → (e2 : Γ ⊢ ` T1 ⇒ T3)
      → (e3 : Γ ⊢ ` T2 ⇒ T3)
      → {lκ : LM.Cont T3 Z}
      → {rκ : RM.Cont T3 Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.case₁ lE e2 e3 lκ)) (RM.case₁ rE e2 e3 rκ)
      
    case₂ :  ∀ {Γ T1 T2 T3 Z}
      → {lE : LV.Env Γ}
      → {rE : RV.Env Γ}
      → (E : EnvRelate lE rE)
      → {lv1 : LV.Val (` T1 ⊕ T2)}
      → {rv1 : RV.Val (` T1 ⊕ T2)}
      → (v1 : ValRelate lv1 rv1)
      → (e3 : Γ ⊢ ` T2 ⇒ T3)
      → {lκ : LM.Cont T3 Z}
      → {rκ : RM.Cont T3 Z}
      → (κ : ContRelate lκ rκ)
      --------
      → PreContRelate ( (LM.case₂ lE lv1 e3 lκ)) (RM.case₂ rE rv1 e3 rκ)
      
    case₃ : ∀ {T1 T2 T3 Z}
      → {lv1 : LV.Val (` T1 ⊕ T2)}
      → {rv1 : RV.Val (` T1 ⊕ T2)}
      → (v1 : ValRelate lv1 rv1)
      → {lv2 : LV.Val (` T1 ⇒ T3)}
      → {rv2 : RV.Val (` T1 ⇒ T3)}
      → (v2 : ValRelate lv2 rv2)
      → {lκ : LM.Cont T3 Z}
      → {rκ : RM.Cont T3 Z}
      → (κ : ContRelate lκ rκ)
      ----------------
      → PreContRelate ( (LM.case₃ lv1 lv2 lκ)) (RM.case₃ rv1 rv2 rκ)
  
data StateRelate : {T : Type} → LM.State T → RM.State T → Set where
  inspect : ∀ {Γ T1 T3}
    → (e : Γ ⊢ T1)
    → {lE : LV.Env Γ}
    → {rE : RV.Env Γ}
    → (E : EnvRelate lE rE)
    → {lκ : LM.Cont T1 T3}
    → {rκ : RM.Cont T1 T3}
    → (κ : ContRelate lκ rκ)
    ------------
    → StateRelate (LM.inspect e lE lκ) (RM.inspect e rE rκ)
    
  return : ∀ {T1 T2}
    → {lv1 : LV.Val T1}
    → {rv1 : RV.Val T1}
    → (v1 : ValRelate lv1 rv1)
    → {lκ : LM.Cont T1 T2}
    → {rκ : RM.Cont T1 T2}
    → (κ : ContRelate lκ rκ)
    ------------
    → StateRelate (LM.return lv1 lκ) (RM.return rv1 rκ)

  halt : ∀ {T}
    → (o : Observe T)
    → StateRelate (LM.halt o) (RM.halt o)

lcont : ∀ {T1 T2}
  → {lk : LM.Cont T1 T2}
  → {rk : RM.Cont T1 T2}
  → (kk : ContRelate lk rk)
  ---
  → LM.Cont T1 T2
lcont {lk = lk} kk = lk

rcont : ∀ {T1 T2}
  → {lk : LM.Cont T1 T2}
  → {rk : RM.Cont T1 T2}
  → (kk : ContRelate lk rk)
  ---
  → RM.Cont T1 T2
rcont {rk = rk} kk = rk

lstate : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → (ss : StateRelate ls rs)
  ---
  → LM.State T
lstate {ls = ls} ss = ls

rstate : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → (ss : StateRelate ls rs)
  ---
  → RM.State T
rstate {rs = rs} ss = rs

data StateRelate* : {T : Type} → LM.State T → RM.State T → Set where
  done : ∀ {T}
    → {lS : LM.State T}
    → {rS : RM.State T}
    → (ss : StateRelate lS rS)
    → StateRelate* lS rS
  step : ∀ {T}
    → {lS2 : LM.State T}
    → {rS1 : RM.State T}
    → (ss : StateRelate* lS2 (RP.progress rS1))
    → StateRelate* lS2 rS1

count-steps : ∀ {T}
  → {lS : LM.State T}
  → {rS : RM.State T}
  → StateRelate* lS rS
  → Σ[ n ∈ ℕ ] StateRelate lS (repeat n RP.progress rS)
count-steps (done ss) = ⟨ 0 , ss ⟩
count-steps (step ss) with count-steps ss
count-steps (step ss) | ⟨ n , prf ⟩ = ⟨ (suc n) , prf ⟩

ext-cont-id : ∀ {T1 T2}
  → {lk : LM.Cont T1 T2}
  → {rk : RM.Cont T1 T2}
  → (k : ContRelate lk rk)
  ---
  → ContRelate (LM.ext-cont (L.mk-id T1) lk) rk
ext-cont-id {lk = LM.cont fst snd} k rewrite L.monoid-id-l fst
  = k

ext-cont-seq : ∀ {T1 T2 T3 T4}
  → (c1 : L.Cast T1 T2)
  → (c2 : L.Cast T2 T3)
  → (k : LM.Cont T3 T4)
  ---
  → LM.ext-cont (L.mk-seq c1 c2) k ≡ LM.ext-cont c1 (LM.ext-cont c2 k)
ext-cont-seq c1 c2 (LM.cont fst snd)
  rewrite L.monoid-assoc c1 c2 fst
  = refl

lem-do-app : ∀ {Γ T1 T2 T3 T4 T5 T6}
  → (E : LV.Env Γ)
  → (c₁ : L.Cast T3 T1)
  → (b : Γ , T1 ⊢ T2)
  → (c₂ : L.Cast T2 T4)
  → (c₃ : L.Cast T4 T5)
  → (rand : LV.Val T3)
  → (k : LM.Cont T5 T6)
  → LM.do-app (LV.fun E c₁ b (L.mk-seq c₂ c₃)) rand k
    ≡
    LM.do-app (LV.fun E c₁ b c₂) rand (LM.ext-cont c₃ k)
lem-do-app E c₁ b c₂ c₃ rand k with L.apply-cast c₁ rand
lem-do-app E c₁ b c₂ c₃ rand k | LV.succ v rewrite ext-cont-seq c₂ c₃ k = refl
lem-do-app E c₁ b c₂ c₃ rand k | LV.fail l = refl

do-app : ∀ {T1 T2 Z}
  → {lv1 : LV.Val (` T1 ⇒ T2)}
  → {rv1 : RV.Val (` T1 ⇒ T2)}
  → ValRelate lv1 rv1
  → {lv2 : LV.Val T1}
  → {rv2 : RV.Val T1}
  → ValRelate lv2 rv2
  → {lk : LM.Cont T2 Z}
  → {rk : RM.Cont T2 Z}
  → ContRelate lk rk
  → StateRelate* (LM.do-app lv1 lv2 lk)
                 (RP.do-app rv1 rv2 rk)
do-app (fun E b) rand k
  rewrite L.lem-id _ (lval rand)
  = done (inspect b (rand ∷ E) (ext-cont-id k))
do-app (cast-fun l T3 T4 T5 T6 E c1 b c2 {g = g} rator) rand k
  rewrite lem-do-app E (L.mk-seq (L.mk-cast l T5 T3) c1) b c2 (L.mk-cast l T4 T6) (lval rand) (lcont k)
  = step (helper (apply-cast (cast l T5 T3) rand))
  where
    helper : CastResultRelate (L.apply-cast (L.mk-cast l T5 T3) (lval rand)) (RC.apply-cast (RC.mk-cast l T5 T3) (rval rand))
      → StateRelate* (LM.do-app (LV.fun E (L.mk-seq (L.mk-cast l T5 T3) c1) b c2)
                                (lval rand)
                                (LM.ext-cont (L.mk-cast l T4 T6) (lcont k)))
                     (RP.progress
                        (RM.return (rval rand)
                          (RM.cast (RC.cast l T5 T3)
                          (RM.app₂ g (RM.cast (RC.cast l T4 T6) (rcont k))))))
    helper p
      rewrite L.lem-seq (L.mk-cast l T5 T3) c1 (lval rand)
      with L.apply-cast (L.mk-cast l T5 T3) (lval rand) | RC.apply-cast (RC.mk-cast l T5 T3) (rval rand) | p
    ... | LV.succ _ | RV.succ _ | succ rand₁ = step (do-app rator rand₁ (ext-cont l T4 T6 k))
    ... | LV.fail _ | RV.fail _ | fail l₁ = done (halt (blame l₁))

lem-do-car : ∀ {T1 T2 T3 T4 T5 T6 Z}
  → (l : Label)
  → (v1   : LV.Val T1)
  → (c1   : L.Cast T1 T3)
  → (v2   : LV.Val T2)
  → (c2   : L.Cast T2 T4)
  → (lk   : LM.Cont T5 Z)
  → (LM.do-car
       (LV.cons v1 (L.mk-seq c1 (L.mk-cast l T3 T5))
                v2 (L.mk-seq c2 (L.mk-cast l T4 T6)))
       lk)
    ≡
    (LM.do-car
       (LV.cons v1 c1
                v2 c2)
       (LM.ext-cont (L.mk-cast l T3 T5) lk))
lem-do-car l v1 c1 v2 c2 (LM.cont fst snd)
  rewrite L.monoid-assoc c1 (L.mk-cast l _ _) fst
  = refl

do-car : ∀ {T1 T2 Z}
  → {lv : LV.Val (` T1 ⊗ T2)}
  → {rv : RV.Val (` T1 ⊗ T2)}
  → ValRelate lv rv
  → {lk : LM.Cont T1 Z}
  → {rk : RM.Cont T1 Z}
  → ContRelate lk rk
  → StateRelate* (LM.do-car lv lk) (RP.do-car rv rk)
do-car (cons v v₁) k = done (return v (ext-cont-id k))
do-car (cast-cons l T3 T4 T5 T6 v1 c1 v2 c2 v) k
  rewrite lem-do-car {T6 = T6} l v1 c1 v2 c2 (lcont k)
  = step (do-car v (ext-cont l T3 T5 k))

lem-do-cdr : ∀ {T1 T2 T3 T4 T5 T6 Z}
  → (l : Label)
  → (v1   : LV.Val T1)
  → (c1   : L.Cast T1 T3)
  → (v2   : LV.Val T2)
  → (c2   : L.Cast T2 T4)
  → (lk   : LM.Cont T6 Z)
  → (LM.do-cdr
       (LV.cons v1 (L.mk-seq c1 (L.mk-cast l T3 T5))
                v2 (L.mk-seq c2 (L.mk-cast l T4 T6)))
       lk)
    ≡
    (LM.do-cdr
       (LV.cons v1 c1
                v2 c2)
       (LM.ext-cont (L.mk-cast l T4 T6) lk))
lem-do-cdr l v1 c1 v2 c2 (LM.cont fst snd)
  rewrite L.monoid-assoc c2 (L.mk-cast l _ _) fst
  = refl

do-cdr : ∀ {T1 T2 Z}
  → {lv : LV.Val (` T1 ⊗ T2)}
  → {rv : RV.Val (` T1 ⊗ T2)}
  → ValRelate lv rv
  → {lk : LM.Cont T2 Z}
  → {rk : RM.Cont T2 Z}
  → ContRelate lk rk
  → StateRelate* (LM.do-cdr lv lk) (RP.do-cdr rv rk)
do-cdr (cons v1 v2) k = done (return v2 (ext-cont-id k))
do-cdr (cast-cons l T3 T4 T5 T6 v1 c1 v2 c2 v) k
  rewrite lem-do-cdr {T5 = T5} l v1 c1 v2 c2 (lcont k)
  = step (do-cdr v (ext-cont l T4 T6 k))

lem-ext-cont : ∀ {T1 T2 T3 T4 Z}
  → (c1 : L.Cast T1 T2)
  → (c2 : L.Cast T2 T3)
  → (c3 : L.Cast T3 T4)
  → (k : LM.Cont T4 Z)
  → LM.ext-cont (L.mk-seq c1 c2) (LM.ext-cont c3 k)
    ≡
    LM.ext-cont c1 (LM.ext-cont (L.mk-seq c2 c3) k)
lem-ext-cont c1 c2 c3 (LM.cont c4 k)
  rewrite L.monoid-assoc c1 c2 (L.mk-seq c3 c4)
        | L.monoid-assoc c2 c3 c4
  = refl

cap-fun : ∀ {Γ T1 T2 T3 T4}
  → {env : LV.Env Γ}
  → {c1 : L.Cast T3 T1}
  → {e : Γ , T1 ⊢ T2}
  → {c2 : L.Cast T2 T4}
  → {rv : RV.Val (` T3 ⇒ T4)}
  → (v : ValRelate (LV.fun env c1 e c2) rv)
  → (l : Label)
  → ∀ T5
  ---
  → ValRelate (LV.fun env
                      (L.mk-seq (L.mk-cast l T5 T3) c1)
                      e
                      c2)
              (RV.cast rv ⌣⇒ (RC.cast l (` T3 ⇒ T4) (` T5 ⇒ T4)))
cap-fun {T4 = T4} {c2 = c2} v l T5 with cast-fun l _ _ T5 T4 _ _ _ _ v
... | r
  rewrite L.lem-cast-id-is-id l T4
        | L.monoid-id-r c2
  = r              
  

do-case : ∀ {T1 T2 T3 Z}
  → {lv1 : LV.Val (` T1 ⊕ T2)}
  → {rv1 : RV.Val (` T1 ⊕ T2)}
  → ValRelate lv1 rv1
  → {lv2 : LV.Val (` T1 ⇒ T3)}
  → {rv2 : RV.Val (` T1 ⇒ T3)}
  → ValRelate lv2 rv2
  → {lv3 : LV.Val (` T2 ⇒ T3)}
  → {rv3 : RV.Val (` T2 ⇒ T3)}
  → ValRelate lv3 rv3
  → {lk : LM.Cont T3 Z}
  → {rk : RM.Cont T3 Z}
  → ContRelate lk rk
  → StateRelate* (LM.do-case lv1 lv2 lv3 lk)
                 (RP.do-case rv1 rv2 rv3 rk)
do-case (inl v1) {lv2 = LV.fun env c1 b c2} v2 v3 k rewrite L.monoid-id-l c1 = done (return v1 (mk-cont (app₂ v2 k)))
do-case (inr v1) v2 {lv3 = LV.fun env c1 b c2} v3 k rewrite L.monoid-id-l c1 = done (return v1 (mk-cont (app₂ v3 k)))
do-case (cast-inl lv lc v1 l) {lv2 = LV.fun _ c _ _} v2 {lv3 = LV.fun _ _ _ _} v3 k with do-case v1 (cap-fun v2 l _) (cap-fun v3 l _) k
... | tmp rewrite L.monoid-assoc lc (L.mk-cast l _ _) c = step tmp
do-case (cast-inr lv lc v1 l) {lv2 = LV.fun _ _ _ _} v2 {lv3 = LV.fun _ c _ _} v3 k with do-case v1 (cap-fun v2 l _) (cap-fun v3 l _) k
... | tmp rewrite L.monoid-assoc lc (L.mk-cast l _ _) c = step tmp

observe-val : ∀ {T}
  → {lv : LV.Val T}
  → {rv : RV.Val T}
  → ValRelate lv rv
  → LM.observe-val lv ≡ RP.observe-val rv
observe-val (inj P v) = refl
observe-val (fun E b) = refl
observe-val (cast-fun l T3 T4 T5 T6 lE c1 b c2 v) = refl
observe-val sole = refl
observe-val cast-sole = refl
observe-val (cons v v₁) = refl
observe-val (cast-cons l T3 T4 T5 T6 v1 c1 v2 c2 v) = refl
observe-val (inl x) = refl
observe-val (cast-inl lv lc v l) with RP.observe-val (rval v) | observe-val v
... | inl | refl = refl
observe-val (inr x) = refl
observe-val (cast-inr lv lc v l) with RP.observe-val (rval v) | observe-val v
... | inr | refl = refl
  
progress*-return : ∀ {T Z}
  → {lv : LV.Val T}
  → {rv : RV.Val T}
  → ValRelate lv rv
  → {lk : LM.PreCont T Z}
  → {rk : RM.Cont T Z}
  → PreContRelate lk rk
  ---
  → StateRelate* (LM.progress-return lv lk) (RP.progress (RM.return rv rk))
progress*-return v mt with LM.observe-val (lval v) | RP.observe-val (rval v) | observe-val v
... | _ | _ | refl = done (halt (done _))
progress*-return v (cons₁ E e1 κ) = done (inspect e1 E (mk-cont (cons₂ v κ)))
progress*-return v (cons₂ v1 κ) = done (return (cons v1 v) κ)
progress*-return v (inl κ) = done (return (inl v) κ)
progress*-return v (inr κ) = done (return (inr v) κ)
progress*-return v (app₁ E e2 κ) = done (inspect e2 E (mk-cont (app₂ v κ)))
progress*-return v (app₂ v1 κ) = do-app v1 v κ
progress*-return v (car κ) = do-car v κ
progress*-return v (cdr κ) = do-cdr v κ
progress*-return v (case₁ E e2 e3 κ)
  = done (inspect e2 E (mk-cont (case₂ E v e3 κ)))
progress*-return v (case₂ E v1 e3 κ)
  = done (inspect e3 E (mk-cont (case₃ v1 v κ)))
progress*-return v (case₃ v1 v2 κ) = do-case v1 v2 v κ

progress-ret : ∀ {T1 Z}
  → {lv : LV.Val T1}
  → {rv : RV.Val T1}
  → ValRelate lv rv
  → {lk : LM.Cont T1 Z}
  → {rk : RM.Cont T1 Z}
  → ContRelate lk rk
  → StateRelate* (LM.progress (LM.return lv lk))
                 (RP.progress (RM.return rv rk))
progress-ret v (mk-cont k)
  rewrite L.lem-id _ (lval v)
  = progress*-return v k
progress-ret v (ext-cont l T1 T2 {lk = (LM.cont fst snd)} k)
  = prf (do-cast l T1 T2 v)
  where
    prf : CastResultRelate (L.apply-cast (L.mk-cast l T1 T2) (lval v))
                           (RC.do-cast l T1 T2 (rval v))
      → StateRelate* (LM.progress (LM.return (lval v) (LM.ext-cont (L.mk-cast l T1 T2) (lcont k))))
                     (RP.progress (RM.return (rval v) (RM.cast (RC.mk-cast l T1 T2) (rcont k))))
    prf p
      rewrite L.lem-seq (L.mk-cast l T1 T2) fst (lval v)
      with (L.apply-cast (L.mk-cast l T1 T2) (lval v)) | (RC.do-cast l T1 T2 (rval v)) | p
    ... | LV.succ _ | RV.succ _ | succ v₁ = step (progress-ret v₁ k)
    ... | LV.fail _ | RV.fail _ | fail l₁ = done (halt (blame l₁))

progress* : ∀ {T}
  → {lS : LM.State T}
  → {rS : RM.State T}
  → StateRelate lS rS
  → StateRelate* (LM.progress lS) (RP.progress rS)
progress* (inspect (var x) E κ) = done (return (E [ x ]) κ)
progress* (inspect sole E κ) = done (return sole κ)
progress* (inspect (lam T1 T2 e) E κ) = done (return (fun E e) κ)
progress* (inspect (cons e e₁) E κ) = done (inspect e E (mk-cont (cons₁ E e₁ κ)))
progress* (inspect (inl e) E κ) = done (inspect e E (mk-cont (inl κ)))
progress* (inspect (inr e) E κ) = done (inspect e E (mk-cont (inr κ)))
progress* (inspect (app e e₁) E κ) = done (inspect e E (mk-cont (app₁ E e₁ κ)))
progress* (inspect (car e) E κ) = done (inspect e E (mk-cont (car κ)))
progress* (inspect (cdr e) E κ) = done (inspect e E (mk-cont (cdr κ)))
progress* (inspect (case e e₁ e₂) E κ) = done (inspect e E (mk-cont (case₁ E e₁ e₂ κ)))
progress* (inspect (cast l T1 T2 e) E κ) = done (inspect e E (ext-cont l _ _ κ))
progress* (inspect (blame l) E κ) = done (halt (blame l))
progress* (return v k) = progress-ret v k
progress* (halt o) = done (halt o)

weak-bisimulation : ∀ {T}
  → {lS : LM.State T}
  → {rS : RM.State T}
  → StateRelate lS rS
  ---
  → Σ[ n ∈ ℕ ] StateRelate (LM.progress lS) (repeat n RP.progress (RP.progress rS))
weak-bisimulation sr = count-steps (progress* sr)

load : ∀ {T} → (e : ∅ ⊢ T) → StateRelate (LM.load e) (RM.load e)
load e = inspect e [] (mk-cont mt)

lem-evalo-l : ∀ {T}
  → (n : ℕ)
  → {ls : LM.State T}
  → {rs : RM.State T}
  → (ss : StateRelate ls rs)
  → (o : Observe T)
  → repeat n LM.progress ls ≡ LM.halt o
  ---
  → Σ[ m ∈ ℕ ] (repeat m RP.progress rs ≡ RM.halt o)
lem-evalo-l zero (halt _) o refl = ⟨ zero , refl ⟩
lem-evalo-l (suc n) ss o p with weak-bisimulation ss
lem-evalo-l (suc n) ss o p | ⟨ m0 , ss' ⟩ with lem-evalo-l n ss' o p
lem-evalo-l (suc n) ss o p | ⟨ m0 , ss' ⟩ | ⟨ m1 , prf ⟩
  rewrite thm-repeat m1 m0 RP.progress (RP.progress (rstate ss))
  = ⟨ (suc (m1 + m0)) , prf ⟩

thm-evalo-l : ∀ {T}
  → {e : ∅ ⊢ T}
  → {o : Observe T}
  → LM.Evalo e o
  ---
  → RP.Evalo e o
thm-evalo-l {e = e} {o = o} (LM.evalo n prf) with lem-evalo-l n (load e) o prf
thm-evalo-l (LM.evalo n prf) | ⟨ m , x ⟩ = RP.evalo m x

fast-halt : ∀ {T}
  → (o : Observe T)
  → {ls : LM.State T}
  → (s : StateRelate* ls (RM.halt o))
  ---
  → ls ≡ LM.halt o
fast-halt o (done (halt _)) = refl
fast-halt o (step s) = fast-halt o s

mutual
  lem-evalo-r* : ∀ {T}
    → (n : ℕ)
    → {ls : LM.State T}
    → {rs : RM.State T}
    → (ss : StateRelate* ls rs)
    → (o : Observe T)
    → repeat n RP.progress rs ≡ RM.halt o
    ---
    → Σ[ m ∈ ℕ ] (repeat m LM.progress ls ≡ LM.halt o)
  lem-evalo-r* n (done ss) o p = lem-evalo-r n ss o p
  lem-evalo-r* zero (step ss) o refl with fast-halt o ss
  ... | refl = ⟨ zero , refl ⟩
  lem-evalo-r* (suc n) (step ss) o p = lem-evalo-r* n ss o p
  
  lem-evalo-r : ∀ {T}
    → (n : ℕ)
    → {ls : LM.State T}
    → {rs : RM.State T}
    → (ss : StateRelate ls rs)
    → (o : Observe T)
    → repeat n RP.progress rs ≡ RM.halt o
    ---
    → Σ[ m ∈ ℕ ] (repeat m LM.progress ls ≡ LM.halt o)
  lem-evalo-r zero (halt _) o refl = ⟨ zero , refl ⟩
  lem-evalo-r (suc n) ss o p with lem-evalo-r* n (progress* ss) o p
  lem-evalo-r (suc n) ss o p | ⟨ m , prf ⟩ = ⟨ (suc m) , prf ⟩
  
thm-evalo-r : ∀ {T}
  → {e : ∅ ⊢ T}
  → {o : Observe T}
  → RP.Evalo e o
  ---
  → LM.Evalo e o
thm-evalo-r {e = e} {o = o} (RP.evalo n prf) with lem-evalo-r n (load e) o prf
thm-evalo-r (RP.evalo n prf) | ⟨ m , x ⟩ = LM.evalo m x






--- theorems in the paper


data HaltL {T : Type} : LM.State T → Set where
  halt : ∀ o
    → HaltL (LM.halt o)

data HaltR {T : Type} : RM.State T → Set where
  halt : ∀ o
    → HaltR (RM.halt o)

lem-both-halt-l : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → HaltL ls
  ---
  → HaltR rs
lem-both-halt-l (halt .o) (halt o) = halt o

lem-both-halt-r : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → HaltR rs
  ---
  → HaltL ls
lem-both-halt-r (halt .o) (halt o) = halt o

_≈_ : ∀ {T}
  → (ls : LM.State T)
  → (rs : RM.State T)
  → Set
ls ≈ rs = StateRelate ls rs

data _−→L_ {T : Type} : LM.State T → LM.State T → Set where
  it : ∀ {s}
    → ¬ HaltL s
    → s −→L (LM.progress s)

data _−→R_ {T : Type} : RM.State T → RM.State T → Set where
  it : ∀ {s}
    → ¬ HaltR s
    → s −→R (RP.progress s)

data _−→R*_ {T : Type} : RM.State T → RM.State T → Set where
  refl : ∀ {s}
    → s −→R* s
  tran : ∀ {r s t}
    → r −→R s
    → s −→R* t
    ---
    → r −→R* t

lem-not-halt-l :  ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → ¬ HaltL ls
  ---
  → ¬ HaltR rs
lem-not-halt-l s p = λ x → ⊥-elim (p (lem-both-halt-r s x))

lem-not-halt-r :  ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → ¬ HaltR rs
  ---
  → ¬ HaltL ls
lem-not-halt-r s p = λ x → ⊥-elim (p (lem-both-halt-l s x))

lem-both-progress-l : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → Σ[ ls' ∈ LM.State T ] ls −→L ls'
  ---
  → Σ[ rs' ∈ RM.State T ] rs −→R rs'
lem-both-progress-l s ⟨ _ , it x ⟩ = ⟨ _ , it (lem-not-halt-l s x) ⟩

lem-both-progress-r : ∀ {T}
  → {ls : LM.State T}
  → {rs : RM.State T}
  → StateRelate ls rs
  → Σ[ rs' ∈ RM.State T ] rs −→R rs'
  ---
  → Σ[ ls' ∈ LM.State T ] ls −→L ls'
lem-both-progress-r s ⟨ _ , it x ⟩ = ⟨ _ , it (lem-not-halt-r s x) ⟩

-- lem-preserve : ∀ {T}
--   → {ls ls' : LM.State T}
--   → {rs rs' : RM.State T}
--   → StateRelate ls rs
--   → ls −→L ls'
--   → rs −→R rs'
--   ---
--   → StateRelate* ls' rs'
-- lem-preserve s lp rp = {!!}
