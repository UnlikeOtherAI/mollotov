import { describe, it, expect, vi, afterEach } from "vitest";
import { executeGroup, executeSmartQuery } from "../../src/group/orchestrator.js";
import { filterDevices } from "../../src/group/filter.js";
import type { DiscoveredDevice } from "../../src/types.js";

function makeDevice(overrides: Partial<DiscoveredDevice> = {}): DiscoveredDevice {
  return {
    id: "d1",
    name: "iPhone",
    ip: "192.168.1.10",
    port: 8420,
    platform: "ios",
    model: "iPhone 15",
    width: 390,
    height: 844,
    version: "1.0.0",
    lastSeen: Date.now(),
    ...overrides,
  };
}

const devices = [
  makeDevice({ id: "d1", name: "iPhone", platform: "ios" }),
  makeDevice({ id: "d2", name: "Pixel", platform: "android", ip: "192.168.1.11", width: 412, height: 915 }),
  makeDevice({ id: "d3", name: "iPad", platform: "ios", ip: "192.168.1.12", width: 1024, height: 1366 }),
];

describe("filterDevices", () => {
  it("filters by platform", () => {
    const ios = filterDevices(devices, { platform: "ios" });
    expect(ios).toHaveLength(2);
    expect(ios.every((d) => d.platform === "ios")).toBe(true);
  });

  it("filters by include", () => {
    const result = filterDevices(devices, { include: "iPhone,Pixel" });
    expect(result).toHaveLength(2);
  });

  it("filters by exclude", () => {
    const result = filterDevices(devices, { exclude: "iPad" });
    expect(result).toHaveLength(2);
    expect(result.find((d) => d.name === "iPad")).toBeUndefined();
  });

  it("intersects platform and include", () => {
    const result = filterDevices(devices, { platform: "ios", include: "iPhone" });
    expect(result).toHaveLength(1);
    expect(result[0].name).toBe("iPhone");
  });
});

describe("executeGroup", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("sends to all devices in parallel", async () => {
    const calls: string[] = [];
    globalThis.fetch = vi.fn(async (url: string | URL | Request) => {
      calls.push(url as string);
      return new Response(JSON.stringify({ success: true, url: "https://example.com" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }) as typeof fetch;

    const result = await executeGroup(devices, "navigate", { url: "https://example.com" }, 5000);
    expect(calls).toHaveLength(3);
    expect(result.deviceCount).toBe(3);
    expect(result.succeeded).toBe(3);
    expect(result.failed).toBe(0);
  });

  it("handles partial failures", async () => {
    let callIndex = 0;
    globalThis.fetch = vi.fn(async () => {
      callIndex++;
      if (callIndex === 2) {
        return new Response(JSON.stringify({ success: false, error: { code: "NAVIGATION_ERROR", message: "DNS failed" } }), {
          status: 502,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(JSON.stringify({ success: true }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }) as typeof fetch;

    const result = await executeGroup(devices, "navigate", { url: "https://example.com" }, 5000);
    expect(result.succeeded).toBe(2);
    expect(result.failed).toBe(1);
  });
});

describe("executeSmartQuery", () => {
  const originalFetch = globalThis.fetch;

  afterEach(() => {
    globalThis.fetch = originalFetch;
  });

  it("partitions into found/notFound", async () => {
    let callIndex = 0;
    globalThis.fetch = vi.fn(async () => {
      callIndex++;
      if (callIndex === 3) {
        return new Response(JSON.stringify({ found: false }), {
          status: 200,
          headers: { "Content-Type": "application/json" },
        });
      }
      return new Response(
        JSON.stringify({ found: true, element: { tag: "button", text: "Submit" } }),
        { status: 200, headers: { "Content-Type": "application/json" } },
      );
    }) as typeof fetch;

    const result = await executeSmartQuery(devices, "findButton", { text: "Submit" }, 5000);
    expect(result.found).toHaveLength(2);
    expect(result.notFound).toHaveLength(1);
    expect(result.notFound[0].device.name).toBe("iPad");
  });
});
