import { describe, expect, it } from "vitest";
import { CATEGORIES, MAX_IMPOSTORS, SEER, SPECIAL_ROLES, TEAM_NAMES, THIEF, VILLAGER, WEREWOLF, TABU_CARDS } from "./gameData";
import {
  autoWerewolves,
  cleanName,
  createMatch,
  drawCard,
  endTurn,
  explainerSeat,
  makeTeams,
  scoreCard,
  watcherSeat,
  watcherTeam,
  tabuProblem,
  dealImpostor,
  dealWerwolf,
  duplicateName,
  impostorProblem,
  knownWolves,
  normalizeRoles,
  pickWord,
  playerNames,
  type Random,
  werwolfProblem,
} from "./localGames";

/** Immer gleiche Zufallsfolge, damit Tests wiederholbar sind. */
function seeded(seed: number): Random {
  let state = seed;
  return () => {
    state = (state * 1103515245 + 12345) % 2147483648;
    return state / 2147483648;
  };
}

const count = (ids: string[], id: string) => ids.filter((x) => x === id).length;
const allCategories = CATEGORIES.map((c) => c.name);

describe("Namen", () => {
  it("füllt leere Felder mit Spieler-Nummern", () => {
    expect(playerNames(4, ["Anna", "  ", "", "Ben"])).toEqual(["Anna", "Spieler 2", "Spieler 3", "Ben"]);
    expect(playerNames(2, [])).toEqual(["Spieler 1", "Spieler 2"]);
  });

  it("entfernt unsichtbare Zeichen", () => {
    expect(cleanName("Rich​ard")).toBe("Richard");
    expect(cleanName("  Ri \t chard ")).toBe("Ri chard");
  });

  it("findet doppelte Namen ohne Groß- und Kleinschreibung", () => {
    expect(duplicateName(["Anna", "Ben", "anna"])).toBe("anna");
    expect(duplicateName(["Anna", "Ben"])).toBeNull();
  });
});

describe("Werwolf", () => {
  it("verteilt Werwölfe automatisch nach Spielerzahl", () => {
    expect([4, 7, 8, 12].map(autoWerewolves)).toEqual([1, 1, 2, 3]);
  });

  it("gibt jedem genau eine Karte, Rest Dorfbewohner", () => {
    const deal = dealWerwolf(8, null, [SEER], seeded(1));
    const ids = deal.perPlayer.map((r) => r.id);
    expect(ids).toHaveLength(8);
    expect(count(ids, WEREWOLF)).toBe(2);
    expect(count(ids, SEER)).toBe(1);
    expect(count(ids, VILLAGER)).toBe(5);
    expect(deal.leftover).toEqual([]);
  });

  it("blockiert zu viele Rollen", () => {
    expect(werwolfProblem(4, 2, [SEER, "HEXE", "JAEGER"])).toBe(
      "Zu viele Rollen: 5 Rollen für 4 Spieler. Nimm Rollen raus oder weniger Werwölfe.",
    );
    expect(werwolfProblem(3, null, [])).toBe("Es werden mindestens 4 Spieler gebraucht.");
    expect(() => dealWerwolf(4, 2, [SEER, "HEXE", "JAEGER"], seeded(1))).toThrow();
  });

  it("legt mit Dieb zwei Karten zur Seite", () => {
    const deal = dealWerwolf(5, null, [THIEF], seeded(3));
    expect(deal.perPlayer).toHaveLength(5);
    expect(deal.leftover).toHaveLength(2);
  });

  it("Rudel kennt sich, Günstling kennt das Rudel, aber nicht umgekehrt", () => {
    const names = ["A", "B", "C", "D", "E", "F"];
    for (let seed = 0; seed < 20; seed++) {
      const deal = dealWerwolf(6, 1, ["URWOLF", "GUENSTLING"], seeded(seed));
      deal.perPlayer.forEach((role, i) => {
        const known = knownWolves(deal, names, i);
        if (role.id === "GUENSTLING") expect(known).toHaveLength(2);
        else if (role.wolfPack) expect(known).toHaveLength(1);
        else expect(known).toEqual([]);
      });
    }
  });

  it("sortiert die Rollenauswahl wie die Rollenliste", () => {
    expect(normalizeRoles(["JAEGER", "QUATSCH", "HEXE"])).toEqual(["HEXE", "JAEGER"]);
  });

  it("jede Sonderrolle hat Namen, Text und ein bekanntes Team", () => {
    expect(SPECIAL_ROLES).toHaveLength(19);
    for (const role of SPECIAL_ROLES) {
      expect(role.name).not.toBe("");
      expect(role.description).not.toBe("");
      expect(TEAM_NAMES[role.team]).toBeDefined();
    }
  });
});

describe("Impostor", () => {
  it("braucht ab zwei Impostorn genug Mitspieler", () => {
    expect(impostorProblem(3, 1)).toBeNull();
    expect(impostorProblem(2, 1)).toBe("Für Impostor braucht es mindestens 3 Mitspieler.");
    expect(impostorProblem(5, 2)).toBe("Für 2 Impostor braucht es mindestens 6 Mitspieler.");
    expect(impostorProblem(6, 2)).toBeNull();
    expect(impostorProblem(20, MAX_IMPOSTORS + 1)).not.toBeNull();
  });

  it("lost die gewünschte Zahl Impostor und einen Startspieler aus der Crew", () => {
    for (let seed = 0; seed < 50; seed++) {
      const deal = dealImpostor(6, { impostorCount: 2, randomStartPlayer: true, categories: allCategories }, [], seeded(seed));
      expect(new Set(deal.impostors).size).toBe(2);
      expect(deal.startPlayer).not.toBeNull();
      expect(deal.impostors).not.toContain(deal.startPlayer);
    }
  });

  it("lost keinen Startspieler, wenn ausgeschaltet", () => {
    const deal = dealImpostor(3, { impostorCount: 1, randomStartPlayer: false, categories: allCategories }, [], seeded(1));
    expect(deal.startPlayer).toBeNull();
  });

  it("nimmt nur Wörter aus den gewählten Kategorien und wiederholt keine", () => {
    const tiere = CATEGORIES.find((c) => c.name === "Tiere")!;
    const used: string[] = [];
    const random = seeded(7);
    for (let i = 0; i < tiere.words.length; i++) {
      const { word, category } = pickWord(["Tiere"], used, random);
      expect(category).toBe("Tiere");
      expect(used).not.toContain(word);
      used.push(word);
    }
    // Alle verbraucht: dann geht es von vorne los
    expect(tiere.words).toContain(pickWord(["Tiere"], used, random).word);
  });
});

describe("Tabu", () => {
  it("braucht genug Spieler und vollständige Teams", () => {
    expect(tabuProblem(3, 2, true, [])).toBe("Für 2 Teams braucht es mindestens 4 Spieler.");
    expect(tabuProblem(4, 2, true, [])).toBeNull();
    expect(tabuProblem(4, 2, false, [0, 0, 1, null])).toBe("1 Spieler hat noch kein Team.");
    expect(tabuProblem(4, 2, false, [0, 0, 0, 1])).toBe("Jedes Team braucht mindestens 2 Spieler.");
    expect(tabuProblem(4, 2, false, [0, 1, 0, 1])).toBeNull();
    // Team 3 gibt es bei 2 Teams nicht mehr, das zählt wie keine Wahl
    expect(tabuProblem(4, 2, false, [0, 1, 0, 3])).toBe("1 Spieler hat noch kein Team.");
  });

  it("verteilt automatisch gleich groß und sonst wie gewählt", () => {
    const auto = makeTeams(5, 2, true, [], seeded(1));
    expect(auto.map((t) => t.length)).toEqual([3, 2]);
    expect(auto.flat().sort()).toEqual([0, 1, 2, 3, 4]);
    expect(makeTeams(4, 2, false, [1, 0, 1, 0], seeded(1))).toEqual([[1, 3], [0, 2]]);
  });

  it("Erklärer und Aufpasser kommen aus verschiedenen Teams und wechseln reihum", () => {
    const match = createMatch([[0, 1, 2], [3, 4, 5]], 30);
    const explainers: number[] = [];
    const watchers: number[] = [];
    for (let turn = 0; turn < 6; turn++) {
      expect(match.teams[match.currentTeam]).toContain(explainerSeat(match));
      expect(match.teams[watcherTeam(match)]).toContain(watcherSeat(match));
      if (match.currentTeam === 0) {
        explainers.push(explainerSeat(match));
        watchers.push(watcherSeat(match));
      }
      endTurn(match);
    }
    expect(explainers).toEqual([0, 1, 2]);
    expect(watchers).toEqual([3, 4, 5]);
  });

  it("vergibt Punkte richtig und endet bei den Siegpunkten", () => {
    const random = seeded(4);
    const match = createMatch([[0, 1], [2, 3]], 3);
    drawCard(match, random);
    scoreCard(match, "CORRECT", random);
    scoreCard(match, "SKIPPED", random);
    scoreCard(match, "BUZZED", random);
    expect(match.scores).toEqual([1, 0]);
    expect(match.turnResults.map((r) => r.scoringTeam)).toEqual([0, null, null]);

    scoreCard(match, "CORRECT", random);
    scoreCard(match, "CORRECT", random);
    expect(match.winner).toBe(0);
    expect(match.card).toBeNull();
    expect(match.lastTurn).toHaveLength(5);
    scoreCard(match, "CORRECT", random);
    expect(match.scores).toEqual([3, 0]);
  });

  it("wiederholt keine Karte, bis alle dran waren", () => {
    const random = seeded(9);
    const match = createMatch([[0, 1], [2, 3]], 1000);
    const seen = new Set<string>();
    drawCard(match, random);
    for (let i = 0; i < TABU_CARDS.length; i++) {
      expect(seen.has(match.card!.word)).toBe(false);
      seen.add(match.card!.word);
      scoreCard(match, i % 2 ? "SKIPPED" : "CORRECT", random);
    }
    expect(seen.size).toBe(TABU_CARDS.length);
  });
});
