const { expect } = require("chai");
const { ethers } = require("hardhat");

describe('btfs status test', function () {
    let owner, user;
    beforeEach(async function () {

        [owner, user] = await ethers.getSigners();
        console.log(">>> owner, user:", owner.address, user.address);

        this.Greeter = await ethers.getContractFactory("BtfsStatus", owner);
        this.greeter = await this.Greeter.deploy();

    });

    describe('--- hash', function () {
        it("...", async function() {
            let hash = await this.greeter.genHashExt(
                '1',
                1,
                '1',
                1,
                '0x22df207EC3C8D18fEDeed87752C5a68E5b4f6FbD'
            );
            console.log("...genHashExt hash = ", hash)
            expect(hash).to.equal('0xcdfafb9babc5d7cc865e02493ed47c87b697603d70c6244e2a7c4501ea4d4851');
        });
    })

    describe('--- recover signer', function () {
        it("...", async function() {
            let signedAddress = await this.greeter.recoverSignerExt(
                '0xcdfafb9babc5d7cc865e02493ed47c87b697603d70c6244e2a7c4501ea4d4851',
                '0x1159ba0adc046b7605246c0910de6ff1a11adb8fac63ca8b914b7047d4b2bcf151b2cc314a3d49f5cfc2a0659552ff1efbb8eb7346c352c5ce45f6fd7bdac3e201'
            );
            console.log("...recoverSignerExt signedAddress = ", signedAddress)
            expect(signedAddress).to.equal('0x22df207EC3C8D18fEDeed87752C5a68E5b4f6FbD');
        });
    })


    describe('--- report', function () {
        it("...", async function() {
            await this.greeter.reportStatus(
                '1',
                1,
                '1',
                1,
                '0x22df207EC3C8D18fEDeed87752C5a68E5b4f6FbD',
                '0x1159ba0adc046b7605246c0910de6ff1a11adb8fac63ca8b914b7047d4b2bcf151b2cc314a3d49f5cfc2a0659552ff1efbb8eb7346c352c5ce45f6fd7bdac3e201'
            );

            let s = await this.greeter.getStatus(
                '1',
            );
            console.log("...getStatus s = ", s)

            let num = s[3]
            expect(num).to.equal(1);

        });
    })
});
