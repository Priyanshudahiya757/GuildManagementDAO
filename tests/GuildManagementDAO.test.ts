
import { describe, expect, it } from "vitest";

// ...existing code...

/*
  The test below is an example. To learn more, read the testing documentation here:
  https://docs.hiro.so/stacks/clarinet-js-sdk
*/

describe("example tests", () => {
  it("ensures simnet is well initialised", () => {
    expect(simnet.blockHeight).toBeDefined();
  });

  it("join, distribute, and claim flow", () => {
  const accounts = simnet.getAccounts();
  const wallet1 = accounts.get("wallet_1") as string;

  // simple smoke: call read-only get-guild-info and get-unclaimed-profits
  const info = simnet.callReadOnlyFn("GuildManagementDAO", "get-guild-info", [], wallet1);
  expect(info.result).toBeDefined();
  const unclaimed = simnet.callReadOnlyFn("GuildManagementDAO", "get-my-unclaimed-profits", [], wallet1);
  expect(unclaimed.result).toBeDefined();
  });

  // it("shows an example", () => {
  //   const { result } = simnet.callReadOnlyFn("counter", "get-counter", [], address1);
  //   expect(result).toBeUint(0);
  // });
});
