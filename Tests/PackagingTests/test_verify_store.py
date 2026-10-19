import importlib.util
from datetime import datetime, timedelta, timezone
from pathlib import Path
import unittest
import tempfile
import plistlib
from unittest.mock import patch

source = Path(__file__).resolve().parents[2] / "Scripts/verify-store.py"
spec = importlib.util.spec_from_file_location("verify_store", source)
verify = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verify)


class StoreVerificationTests(unittest.TestCase):
    def test_expected_entitlements_pass(self):
        verify.check_entitlements(dict(verify.REQUIRED_ENTITLEMENTS))

    def test_extra_permissions_are_rejected(self):
        for key in ["com.apple.security.network.client", "get-task-allow"]:
            with self.subTest(key=key), self.assertRaises(verify.VerificationError):
                verify.check_entitlements(dict(verify.REQUIRED_ENTITLEMENTS, **{key: True}))

    def test_missing_sandbox_is_rejected(self):
        with self.assertRaises(verify.VerificationError):
            verify.check_entitlements({})

    def test_audited_privacy_passes_and_tracking_is_rejected(self):
        privacy = verify.read_plist(source.parents[1] / "Packaging/PrivacyInfo.xcprivacy")
        verify.check_privacy(privacy)
        privacy["NSPrivacyTracking"] = True
        with self.assertRaises(verify.VerificationError):
            verify.check_privacy(privacy)

    def test_missing_api_reason_is_rejected(self):
        privacy = verify.read_plist(source.parents[1] / "Packaging/PrivacyInfo.xcprivacy")
        privacy["NSPrivacyAccessedAPITypes"].pop()
        with self.assertRaises(verify.VerificationError):
            verify.check_privacy(privacy)

    def test_profile_expiry_and_app_id_mismatch_are_rejected(self):
        now = datetime(2026, 10, 15, tzinfo=timezone.utc)
        identifier = "TEAM.com.mehrdad.storagefix"
        entitlements = {"com.apple.application-identifier": identifier,
                        "com.apple.developer.team-identifier": "TEAM"}
        profile = {"ExpirationDate": now + timedelta(days=1), "TeamIdentifier": ["TEAM"],
                   "Entitlements": {"com.apple.application-identifier": identifier}}
        verify.check_profile(profile, entitlements, verify.BUNDLE_ID, now)
        profile["ExpirationDate"] = now - timedelta(days=1)
        with self.assertRaises(verify.VerificationError):
            verify.check_profile(profile, entitlements, verify.BUNDLE_ID, now)
        profile["ExpirationDate"] = now + timedelta(days=1)
        profile["Entitlements"]["com.apple.application-identifier"] = "TEAM.other"
        with self.assertRaises(verify.VerificationError):
            verify.check_profile(profile, entitlements, verify.BUNDLE_ID, now)

    def test_profile_preparation_emits_only_required_permissions_and_team_identifiers(self):
        profile = {"ExpirationDate": datetime(2040, 1, 1), "TeamIdentifier": ["TEAM"],
                   "Entitlements": {"com.apple.application-identifier": "TEAM.com.mehrdad.storagefix",
                                    "com.apple.developer.team-identifier": "TEAM"}}
        with tempfile.TemporaryDirectory() as folder:
            output = Path(folder) / "entitlements.plist"
            with patch.object(verify, "run", return_value=plistlib.dumps(profile)):
                verify.prepare_entitlements(Path("synthetic-profile"), output)
            entitlements = verify.read_plist(output)
            verify.check_entitlements(entitlements)
            self.assertEqual(len(entitlements), len(verify.REQUIRED_ENTITLEMENTS) + 2)
            self.assertEqual(entitlements["com.apple.developer.team-identifier"], "TEAM")

    def test_development_and_developer_id_profiles_are_rejected(self):
        now = datetime(2026, 10, 15, tzinfo=timezone.utc)
        for key, value in [("ProvisionedDevices", ["device"]), ("ProvisionsAllDevices", True)]:
            profile = {"ExpirationDate": now + timedelta(days=1), key: value}
            with self.subTest(key=key), self.assertRaises(verify.VerificationError):
                verify.check_profile(profile, {}, verify.BUNDLE_ID, now)


if __name__ == "__main__":
    unittest.main()
