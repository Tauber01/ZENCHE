export class CameraProfile {
  readonly name: string;
  readonly productId: number;
  readonly minimumIso: number;
  readonly maximumIso: number;

  constructor(
    name: string,
    productId: number,
    minimumIso: number,
    maximumIso: number
  ) {
    this.name = name;
    this.productId = productId;
    this.minimumIso = minimumIso;
    this.maximumIso = maximumIso;
  }
}

export const NIKON_VENDOR_ID: number = 0x04b0;

export const SUPPORTED_CAMERAS: Array<CameraProfile> = [
  new CameraProfile('Nikon D500', 0x043a, 100, 51200),
  new CameraProfile('Nikon Z7', 0x0442, 64, 25600),
  new CameraProfile('Nikon Z6', 0x0443, 100, 51200),
  new CameraProfile('Nikon Z50', 0x0444, 100, 51200),
  new CameraProfile('Nikon D7500', 0x0445, 100, 51200),
  new CameraProfile('Nikon D780', 0x0446, 100, 51200),
  new CameraProfile('Nikon D6', 0x0447, 100, 102400),
  new CameraProfile('Nikon Z5', 0x0448, 100, 51200),
  new CameraProfile('Nikon D850', 0x044a, 64, 25600),
  new CameraProfile('Nikon Z7II', 0x044b, 64, 25600),
  new CameraProfile('Nikon Z6II', 0x044c, 100, 51200),
  new CameraProfile('Nikon Z fc', 0x044f, 100, 51200),
  new CameraProfile('Nikon Z9', 0x0450, 64, 25600),
  new CameraProfile('Nikon Z8', 0x0451, 64, 25600),
  new CameraProfile('Nikon Z30', 0x0452, 100, 51200),
  new CameraProfile('Nikon Z f', 0x0453, 100, 64000),
  new CameraProfile('Nikon Z6III', 0x0454, 100, 64000),
  new CameraProfile('Nikon Z50II', 0x0455, 100, 51200),
  new CameraProfile('Nikon Z5II', 0x0456, 100, 64000),
  new CameraProfile('Nikon ZR', 0x0457, 100, 51200)
];

export function profileForProduct(productId: number): CameraProfile | undefined {
  return SUPPORTED_CAMERAS.find((profile: CameraProfile) =>
    profile.productId === productId
  );
}

export function supportedCameraSummary(): string {
  return SUPPORTED_CAMERAS
    .map((profile: CameraProfile) => profile.name.replace('Nikon ', ''))
    .join('、');
}
