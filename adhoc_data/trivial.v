Lemma proj: forall a b: Type, a * b -> b.
Proof.
intros h0 h1 h2.
elim h2.
intros h0' h1'.
apply h1'.
Qed.


Lemma proj2: forall a b: Type, a*b -> b.
intros.
destruct X.
apply b0.
Qed.
