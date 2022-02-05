const { expect } = require("chai");
const { ethers } = require("hardhat");

const { decode, prove, keygen, getFastVerifyComponents } = require("../../vrf");

const alpha = new Date().valueOf().toString();
const keypair = keygen();
const proof = prove(keypair.secret_key, alpha);
const [Gamma, c, s] = decode(proof);

const fast = getFastVerifyComponents(keypair.public_key.key, proof, alpha);

describe("Greeter", function () {
  it("Verify should work", async function () {
    const VRF = await ethers.getContractFactory("TestHelperVRF");
    const vrf = await VRF.deploy();
    await vrf.deployed();

    const isValid = await vrf.verify(
      [keypair.public_key.x.toString(), keypair.public_key.y.toString()],
      [Gamma.x.toString(), Gamma.y.toString(), c.toString(), s.toString()],
      Buffer.from(alpha, "hex")
    );

    expect(isValid).to.be.true;
  });

  it("Fast verify should work", async function () {
    const VRF = await ethers.getContractFactory("TestHelperVRF");
    const vrf = await VRF.deploy();
    await vrf.deployed();

    const isFastValid = await vrf.fastVerify(
      [keypair.public_key.x.toString(), keypair.public_key.y.toString()],
      [Gamma.x.toString(), Gamma.y.toString(), c.toString(), s.toString()],
      Buffer.from(alpha, "hex"),
      [fast.uX, fast.uY],
      [fast.sHX, fast.sHY, fast.cGX, fast.cGY]
    );

    expect(isFastValid).to.be.true;
  });

  it("Fast verify params should compute", async function () {
    const VRF = await ethers.getContractFactory("TestHelperVRF");
    const vrf = await VRF.deploy();
    await vrf.deployed();

    const components = await vrf.computeFastVerifyParams(
      [keypair.public_key.x.toString(), keypair.public_key.y.toString()],
      [Gamma.x.toString(), Gamma.y.toString(), c.toString(), s.toString()],
      Buffer.from(alpha, "hex")
    );

    expect(components.map((arr) => arr.map((n) => n.toString()))).to.deep.equal(
      [
        [fast.uX, fast.uY],
        [fast.sHX, fast.sHY, fast.cGX, fast.cGY],
      ]
    );
  });
});
