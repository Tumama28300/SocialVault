import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

/// Aquest model ens permet escalar l'aplicació a qualsevol xarxa social
/// només afegint un element nou a la llista, sense tocar la interfície.
class SocialNetwork {
  final String id;
  final String name;
  final String passwordChangeUrl;
  final FaIconData icon;
  final Color brandColor;

  const SocialNetwork({
    required this.id,
    required this.name,
    required this.passwordChangeUrl,
    required this.icon,
    required this.brandColor,
  });
}

// Llista de xarxes que suportarà l'app. Cada una té el seu propi bloqueig
// independent, identificat per 'id' (estable encara que canviï el 'name').
const List<SocialNetwork> supportedNetworks = [
  SocialNetwork(
    id: 'instagram',
    name: 'Instagram',
    passwordChangeUrl:
        'https://accountscenter.instagram.com/password_and_security/password/change/',
    icon: FontAwesomeIcons.instagram,
    brandColor: Color(0xFFE1306C),
  ),
  SocialNetwork(
    id: 'tiktok',
    name: 'TikTok',
    passwordChangeUrl: 'https://www.tiktok.com/setting/password',
    icon: FontAwesomeIcons.tiktok,
    brandColor: Color(0xFF00F2EA),
  ),
  SocialNetwork(
    id: 'x',
    name: 'X (Twitter)',
    passwordChangeUrl: 'https://twitter.com/settings/password',
    icon: FontAwesomeIcons.xTwitter,
    brandColor: Color(0xFFFFFFFF),
  ),
];
