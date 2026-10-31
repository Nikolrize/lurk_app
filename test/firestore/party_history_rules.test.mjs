import assert from "node:assert/strict";
import test from "node:test";
import { readFileSync } from "node:fs";
import {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} from "@firebase/rules-unit-testing";
import {
  doc,
  collection,
  getDoc,
  getDocs,
  setDoc,
  deleteDoc,
  writeBatch,
  serverTimestamp,
} from "firebase/firestore";

test("history is private and only records verified atomic participation with authentic summaries", async () => {
  const env = await initializeTestEnvironment({
    projectId: "demo-lurk-history",
    firestore: {
      host: "127.0.0.1",
      port: 8080,
      rules: readFileSync(
        new URL("../../firestore.rules", import.meta.url),
        "utf8",
      ),
    },
  });
  try {
    await env.withSecurityRulesDisabled(c => setDoc(doc(c.firestore(), 'players/bob'), {username:'Bob',region:'Asia'}));
    const alice = env.authenticatedContext("alice").firestore(),
      bob = env.authenticatedContext("bob").firestore(),
      eve = env.authenticatedContext("eve").firestore();
    const fields = () => ({
      title: "History squad",
      hostId: "alice",
      gameId: "valorant",
      region: "asia",
      mode: "competitive",
      visibility: "private",
      maxPlayers: 5,
      memberCount: 1,
      minRank: null,
      maxRank: null,
      playstyles: ["chill"],
      communication: "voice_optional",
      minimumRating: 0,
      description: "",
      status: "open",
      createdAt: serverTimestamp(),
      updatedAt: serverTimestamp(),
      startedAt: null,
      completedAt: null,
    });
    const history = (patch = {}) => ({
      title: "History squad",
      gameId: "valorant",
      mode: "competitive",
      joinedAt: serverTimestamp(),
      ...patch,
    });
    const host = writeBatch(alice);
    host.set(doc(alice, "parties/squad"), fields());
    host.set(doc(alice, "parties/squad/members/alice"), {
      role: "host",
      joinedAt: serverTimestamp(),
      leftAt: null,
    });
    host.set(doc(alice, "party_host_slots/alice"), {
      activeCount: 1,
      lastPartyId: "squad",
      updatedAt: serverTimestamp(),
    });
    host.set(doc(alice, "players/alice/party_history/squad"), history());
    await assertSucceeds(host.commit());
    await assertSucceeds(
      getDocs(collection(alice, "players/alice/party_history")),
    );
    await assertFails(getDocs(collection(bob, "players/alice/party_history")));
    await assertFails(
      getDoc(
        doc(
          env.unauthenticatedContext().firestore(),
          "players/alice/party_history/squad",
        ),
      ),
    );
    await assertFails(
      setDoc(doc(eve, "players/eve/party_history/squad"), history()),
    );
    await env.withSecurityRulesDisabled(async (c) => {
      await setDoc(doc(c.firestore(), "parties/squad/invitations/bob"), {
        hostId: "alice",
        createdAt: new Date(),
      });
    });
    const join = (patch = {}) => {
      const batch = writeBatch(bob);
      batch.set(doc(bob, "parties/squad/members/bob"), {
        role: "member",
        joinedAt: serverTimestamp(),
        leftAt: null,
      });
      batch.update(doc(bob, "parties/squad"), {
        memberCount: 2,
        updatedAt: serverTimestamp(),
      });
      batch.set(doc(bob, "party_memberships/bob"), {
        partyId: "squad",
        updatedAt: serverTimestamp(),
      });
      batch.set(doc(bob, "players/bob/party_history/squad"), history(patch));
      return batch.commit();
    };
    await assertFails(join({ title: "Forged title" }));
    await assertFails(join({ joinedAt: new Date(0) }));
    await assertSucceeds(join());
    const before = (
      await getDoc(doc(bob, "players/bob/party_history/squad"))
    ).data();
    const leave = writeBatch(bob);
    leave.update(doc(bob, "parties/squad/members/bob"), {
      leftAt: serverTimestamp(),
    });
    leave.update(doc(bob, "parties/squad"), {
      memberCount: 1,
      updatedAt: serverTimestamp(),
    });
    leave.delete(doc(bob, "party_memberships/bob"));
    await assertSucceeds(leave.commit());
    await env.withSecurityRulesDisabled(async (c) => {
      await deleteDoc(doc(c.firestore(), "parties/squad/invitations/bob"));
    });
    await assertSucceeds(getDoc(doc(bob, "parties/squad")));
    await assertSucceeds(getDocs(collection(bob, "parties/squad/members")));
    await assertFails(getDoc(doc(eve, "parties/squad")));
    await assertFails(getDocs(collection(eve, "parties/squad/members")));
    assert.equal(
      (
        await assertSucceeds(
          getDoc(doc(bob, "players/bob/party_history/squad")),
        )
      ).data().title,
      before.title,
    );
    await assertSucceeds(getDoc(doc(bob, "parties/squad/members/bob")));
    await assertFails(
      setDoc(
        doc(bob, "players/bob/party_history/squad"),
        history({ title: "Rewritten" }),
      ),
    );
  } finally {
    await env.cleanup();
  }
});
