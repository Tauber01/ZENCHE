export class CameraProfile {
  readonly name: string;
  readonly vendorName: string;
  readonly vendorId: number;
  readonly productId: number;
  readonly minimumIso: number;
  readonly maximumIso: number;

  constructor(
    name: string,
    vendorName: string,
    vendorId: number,
    productId: number,
    minimumIso: number,
    maximumIso: number
  ) {
    this.name = name;
    this.vendorName = vendorName;
    this.vendorId = vendorId;
    this.productId = productId;
    this.minimumIso = minimumIso;
    this.maximumIso = maximumIso;
  }
}

export const SUPPORTED_VENDOR_IDS: Set<number> = new Set<number>([
  0x04b0, 0x054c, 0x04a9
]);

export const SUPPORTED_CAMERAS: Array<CameraProfile> = [
  // ── Nikon EXPEED 5 ──
  new CameraProfile('Nikon D500', 'Nikon', 0x04b0, 0x043a, 100, 51200),
  new CameraProfile('Nikon D7500', 'Nikon', 0x04b0, 0x0445, 100, 51200),
  new CameraProfile('Nikon D850', 'Nikon', 0x04b0, 0x044a, 64, 25600),
  // ── Nikon EXPEED 6 ──
  new CameraProfile('Nikon Z7', 'Nikon', 0x04b0, 0x0442, 64, 25600),
  new CameraProfile('Nikon Z6', 'Nikon', 0x04b0, 0x0443, 100, 51200),
  new CameraProfile('Nikon Z50', 'Nikon', 0x04b0, 0x0444, 100, 51200),
  new CameraProfile('Nikon D780', 'Nikon', 0x04b0, 0x0446, 100, 51200),
  new CameraProfile('Nikon D6', 'Nikon', 0x04b0, 0x0447, 100, 102400),
  new CameraProfile('Nikon Z5', 'Nikon', 0x04b0, 0x0448, 100, 51200),
  new CameraProfile('Nikon Z7II', 'Nikon', 0x04b0, 0x044b, 64, 25600),
  new CameraProfile('Nikon Z6II', 'Nikon', 0x04b0, 0x044c, 100, 51200),
  new CameraProfile('Nikon Z fc', 'Nikon', 0x04b0, 0x044f, 100, 51200),
  new CameraProfile('Nikon Z30', 'Nikon', 0x04b0, 0x0452, 100, 51200),
  // ── Nikon EXPEED 7 ──
  new CameraProfile('Nikon Z9', 'Nikon', 0x04b0, 0x0450, 64, 25600),
  new CameraProfile('Nikon Z8', 'Nikon', 0x04b0, 0x0451, 64, 25600),
  new CameraProfile('Nikon Z f', 'Nikon', 0x04b0, 0x0453, 100, 64000),
  new CameraProfile('Nikon Z6III', 'Nikon', 0x04b0, 0x0454, 100, 64000),
  new CameraProfile('Nikon Z50II', 'Nikon', 0x04b0, 0x0455, 100, 51200),
  new CameraProfile('Nikon Z5II', 'Nikon', 0x04b0, 0x0456, 100, 64000),
  new CameraProfile('Nikon ZR', 'Nikon', 0x04b0, 0x0457, 100, 51200),
  // ── Sony α ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
  // Full-frame E-mount
  new CameraProfile('Sony A1', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony A1 II', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony A9 III', 'Sony', 0x054c, 0x0000, 100, 51200),
  new CameraProfile('Sony A7R V', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony A7 IV', 'Sony', 0x054c, 0x0000, 100, 51200),
  new CameraProfile('Sony A7S III', 'Sony', 0x054c, 0x0000, 80, 102400),
  new CameraProfile('Sony A7C II', 'Sony', 0x054c, 0x0000, 100, 51200),
  new CameraProfile('Sony A7C R', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony ZV-E1', 'Sony', 0x054c, 0x0000, 80, 102400),
  // APS-C E-mount
  new CameraProfile('Sony A6700', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony FX30', 'Sony', 0x054c, 0x0000, 100, 32000),
  new CameraProfile('Sony ZV-E10 II', 'Sony', 0x054c, 0x0000, 100, 32000),
  // ── Canon EOS R ── (Product IDs: TODO — confirm with gphoto2 --auto-detect)
  new CameraProfile('Canon EOS R1', 'Canon', 0x04a9, 0x0000, 100, 102400),
  new CameraProfile('Canon EOS R3', 'Canon', 0x04a9, 0x0000, 100, 102400),
  new CameraProfile('Canon EOS R5', 'Canon', 0x04a9, 0x0000, 100, 51200),
  new CameraProfile('Canon EOS R5 Mark II', 'Canon', 0x04a9, 0x0000, 100, 51200),
  new CameraProfile('Canon EOS R6 Mark II', 'Canon', 0x04a9, 0x0000, 100, 102400),
  new CameraProfile('Canon EOS R7', 'Canon', 0x04a9, 0x0000, 100, 12800),
  new CameraProfile('Canon EOS R8', 'Canon', 0x04a9, 0x0000, 100, 102400),
  new CameraProfile('Canon EOS R10', 'Canon', 0x04a9, 0x0000, 100, 12800),
  new CameraProfile('Canon EOS R50', 'Canon', 0x04a9, 0x0000, 100, 12800),
  new CameraProfile('Canon EOS R100', 'Canon', 0x04a9, 0x0000, 100, 12800),
];

export function profileForProduct(vendorId: number, productId: number): CameraProfile | undefined {
  return SUPPORTED_CAMERAS.find((profile: CameraProfile) =>
    profile.vendorId === vendorId && profile.productId === productId
  );
}

export function supportedCameraSummary(): string {
  return SUPPORTED_CAMERAS
    .map((profile: CameraProfile) => profile.name)
    .join('、');
}
