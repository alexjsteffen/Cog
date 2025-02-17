/***************************************************************************
    copyright            : (C) 2002 - 2008 by Scott Wheeler
    email                : wheeler@kde.org
 ***************************************************************************/

/***************************************************************************
 *   This library is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU Lesser General Public License version   *
 *   2.1 as published by the Free Software Foundation.                     *
 *                                                                         *
 *   This library is distributed in the hope that it will be useful, but   *
 *   WITHOUT ANY WARRANTY; without even the implied warranty of            *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU     *
 *   Lesser General Public License for more details.                       *
 *                                                                         *
 *   You should have received a copy of the GNU Lesser General Public      *
 *   License along with this library; if not, write to the Free Software   *
 *   Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA         *
 *   02110-1301  USA                                                       *
 *                                                                         *
 *   Alternatively, this file is available under the Mozilla Public        *
 *   License Version 1.1.  You may obtain a copy of the License at         *
 *   http://www.mozilla.org/MPL/                                           *
 ***************************************************************************/

#include <tagunion.h>
#include <tstringlist.h>
#include <tpropertymap.h>

#include "id3v1tag.h"
#include "id3v2tag.h"
#include "apetag.h"
#include "xiphcomment.h"
#include "infotag.h"

using namespace TagLib;

#define stringUnion(method)                                          \
  if(tag(0) && !tag(0)->method().isEmpty())                          \
    return tag(0)->method();                                         \
  if(tag(1) && !tag(1)->method().isEmpty())                          \
    return tag(1)->method();                                         \
  if(tag(2) && !tag(2)->method().isEmpty())                          \
    return tag(2)->method();                                         \
  return String();                                                   \

#define numberUnion(method)                                          \
  if(tag(0) && tag(0)->method() > 0)                                 \
    return tag(0)->method();                                         \
  if(tag(1) && tag(1)->method() > 0)                                 \
    return tag(1)->method();                                         \
  if(tag(2) && tag(2)->method() > 0)                                 \
    return tag(2)->method();                                         \
  return 0

#define floatUnion(method)                                           \
  if(tag(0) && tag(0)->method() != 0)                                \
    return tag(0)->method();                                         \
  if(tag(1) && tag(1)->method() != 0)                                \
    return tag(1)->method();                                         \
  if(tag(2) && tag(2)->method() != 0)                                \
    return tag(2)->method();                                         \
  return 0

#define setUnion(method, value)                                      \
  if(tag(0))                                                         \
    tag(0)->set##method(value);                                      \
  if(tag(1))                                                         \
    tag(1)->set##method(value);                                      \
  if(tag(2))                                                         \
    tag(2)->set##method(value);                                      \

class TagUnion::TagUnionPrivate
{
public:
  TagUnionPrivate() : tags(3, static_cast<Tag *>(0))
  {

  }

  ~TagUnionPrivate()
  {
    delete tags[0];
    delete tags[1];
    delete tags[2];
  }

  std::vector<Tag *> tags;
};

TagUnion::TagUnion(Tag *first, Tag *second, Tag *third) :
  d(new TagUnionPrivate())
{
  d->tags[0] = first;
  d->tags[1] = second;
  d->tags[2] = third;
}

TagUnion::~TagUnion()
{
  delete d;
}

Tag *TagUnion::operator[](int index) const
{
  return tag(index);
}

Tag *TagUnion::tag(int index) const
{
  return d->tags[index];
}

void TagUnion::set(int index, Tag *tag)
{
  delete d->tags[index];
  d->tags[index] = tag;
}

PropertyMap TagUnion::properties() const
{
  // This is an ugly workaround but we can't add a virtual function.
  // Should be virtual in taglib2.

  for(size_t i = 0; i < 3; ++i) {

    if(d->tags[i] && !d->tags[i]->isEmpty()) {

      if(dynamic_cast<const ID3v1::Tag *>(d->tags[i]))
        return dynamic_cast<const ID3v1::Tag *>(d->tags[i])->properties();

      else if(dynamic_cast<const ID3v2::Tag *>(d->tags[i]))
        return dynamic_cast<const ID3v2::Tag *>(d->tags[i])->properties();

      else if(dynamic_cast<const APE::Tag *>(d->tags[i]))
        return dynamic_cast<const APE::Tag *>(d->tags[i])->properties();

      else if(dynamic_cast<const Ogg::XiphComment *>(d->tags[i]))
        return dynamic_cast<const Ogg::XiphComment *>(d->tags[i])->properties();

      else if(dynamic_cast<const RIFF::Info::Tag *>(d->tags[i]))
        return dynamic_cast<const RIFF::Info::Tag *>(d->tags[i])->properties();
    }
  }

  return PropertyMap();
}

void TagUnion::removeUnsupportedProperties(const StringList &unsupported)
{
  // This is an ugly workaround but we can't add a virtual function.
  // Should be virtual in taglib2.

  for(size_t i = 0; i < 3; ++i) {

    if(d->tags[i]) {

      if(dynamic_cast<ID3v1::Tag *>(d->tags[i]))
        dynamic_cast<ID3v1::Tag *>(d->tags[i])->removeUnsupportedProperties(unsupported);

      else if(dynamic_cast<ID3v2::Tag *>(d->tags[i]))
        dynamic_cast<ID3v2::Tag *>(d->tags[i])->removeUnsupportedProperties(unsupported);

      else if(dynamic_cast<APE::Tag *>(d->tags[i]))
        dynamic_cast<APE::Tag *>(d->tags[i])->removeUnsupportedProperties(unsupported);

      else if(dynamic_cast<Ogg::XiphComment *>(d->tags[i]))
        dynamic_cast<Ogg::XiphComment *>(d->tags[i])->removeUnsupportedProperties(unsupported);

      else if(dynamic_cast<RIFF::Info::Tag *>(d->tags[i]))
        dynamic_cast<RIFF::Info::Tag *>(d->tags[i])->removeUnsupportedProperties(unsupported);
    }
  }
}

String TagUnion::title() const
{
  stringUnion(title);
}

String TagUnion::albumartist() const
{
  stringUnion(albumartist);
}

String TagUnion::artist() const
{
  stringUnion(artist);
}

String TagUnion::album() const
{
  stringUnion(album);
}

String TagUnion::comment() const
{
  stringUnion(comment);
}

String TagUnion::genre() const
{
  stringUnion(genre);
}

unsigned int TagUnion::year() const
{
  numberUnion(year);
}

unsigned int TagUnion::track() const
{
  numberUnion(track);
}

unsigned int TagUnion::disc() const
{
  numberUnion(disc);
}

String TagUnion::cuesheet() const
{
  stringUnion(cuesheet);
}

float TagUnion::rgAlbumGain() const
{
  floatUnion(rgAlbumGain);
}

float TagUnion::rgAlbumPeak() const
{
  floatUnion(rgAlbumPeak);
}

float TagUnion::rgTrackGain() const
{
  floatUnion(rgTrackGain);
}

float TagUnion::rgTrackPeak() const
{
  floatUnion(rgTrackPeak);
}

String TagUnion::soundcheck() const
{
  stringUnion(soundcheck);
}

void TagUnion::setTitle(const String &s)
{
  setUnion(Title, s);
}

void TagUnion::setAlbumArtist(const String &s)
{
  setUnion(AlbumArtist, s);
}

void TagUnion::setArtist(const String &s)
{
  setUnion(Artist, s);
}

void TagUnion::setAlbum(const String &s)
{
  setUnion(Album, s);
}

void TagUnion::setComment(const String &s)
{
  setUnion(Comment, s);
}

void TagUnion::setGenre(const String &s)
{
  setUnion(Genre, s);
}

void TagUnion::setYear(unsigned int i)
{
  setUnion(Year, i);
}

void TagUnion::setTrack(unsigned int i)
{
  setUnion(Track, i);
}

void TagUnion::setDisc(unsigned int i)
{
  setUnion(Disc, i);
}

void TagUnion::setCuesheet(const String &s)
{
  setUnion(Cuesheet, s);
}

void TagUnion::setRGAlbumGain(float f)
{
  setUnion(RGAlbumGain, f);
}

void TagUnion::setRGAlbumPeak(float f)
{
  setUnion(RGAlbumPeak, f);
}

void TagUnion::setRGTrackGain(float f)
{
  setUnion(RGTrackGain, f);
}

void TagUnion::setRGTrackPeak(float f)
{
  setUnion(RGTrackPeak, f);
}

bool TagUnion::isEmpty() const
{
  if(d->tags[0] && !d->tags[0]->isEmpty())
    return false;
  if(d->tags[1] && !d->tags[1]->isEmpty())
    return false;
  if(d->tags[2] && !d->tags[2]->isEmpty())
    return false;

  return true;
}

